// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IStrategyManager} from
    "@src/interfaces/eigen-layer/IStrategyManager.sol";
import {IStrategy} from "@src/interfaces/eigen-layer/IStrategy.sol";
import {IDelegationManager} from
    "@src/interfaces/eigen-layer/IDelegationManager.sol";
import {IRewardsCoordinator} from
    "@src/interfaces/eigen-layer/IRewardsCoordinator.sol";
import {RewardsHelper} from "./eigen-layer/RewardsHelper.sol";
import {
    RETH,
    EIGEN_LAYER_STRATEGY_MANAGER,
    EIGEN_LAYER_STRATEGY_RETH,
    EIGEN_LAYER_DELEGATION_MANAGER,
    EIGEN_LAYER_REWARDS_COORDINATOR,
    EIGEN_LAYER_OPERATOR
} from "@src/Constants.sol";
import {max} from "@src/Util.sol";

// forge test --fork-url $FORK_URL --match-path test/dev.sol -vvv

contract Dev is Test {
    IRewardsCoordinator constant rewardsCoordinator =
        IRewardsCoordinator(EIGEN_LAYER_REWARDS_COORDINATOR);
    RewardsHelper helper;

    function setUp() public {
        helper = new RewardsHelper(address(rewardsCoordinator));
    }

    function test_claimRewards() public {
        IRewardsCoordinator.RewardsMerkleClaim[] memory claims =
            new IRewardsCoordinator.RewardsMerkleClaim[](1);

        claims[0] = helper.parseProofData("test/eigen-layer/root.json");

        skip(rewardsCoordinator.activationDelay() + 1);

        address earner = helper.earner();
        vm.prank(earner);
        rewardsCoordinator.processClaim(claims[0], earner);

        // TODO: reward balances
        // TODO: claim by restake contract
    }
}

/*
contract EigenLayerMerkle {
    uint8 internal constant EARNER_LEAF_SALT = 0;
    uint8 internal constant TOKEN_LEAF_SALT = 1;

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        address token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    struct DistributionRoot {
        bytes32 root;
        uint32 rewardsCalculationEndTimestamp;
        uint32 activatedAt;
        bool disabled;
    }

    function _checkClaim(RewardsMerkleClaim calldata claim, DistributionRoot memory root) internal view {
        require(!root.disabled, "RewardsCoordinator._checkClaim: root is disabled");
        require(block.timestamp >= root.activatedAt, "RewardsCoordinator._checkClaim: root not activated yet");
        require(
            claim.tokenIndices.length == claim.tokenTreeProofs.length,
            "RewardsCoordinator._checkClaim: tokenIndices and tokenProofs length mismatch"
        );
        require(
            claim.tokenTreeProofs.length == claim.tokenLeaves.length,
            "RewardsCoordinator._checkClaim: tokenTreeProofs and leaves length mismatch"
        );

        // Verify inclusion of earners leaf (earner, earnerTokenRoot) in the distribution root
        _verifyEarnerClaimProof({
            root: root.root,
            earnerLeafIndex: claim.earnerIndex,
            earnerProof: claim.earnerTreeProof,
            earnerLeaf: claim.earnerLeaf
        });
        // For each of the tokenLeaf proofs, verify inclusion of token tree leaf again the earnerTokenRoot
        for (uint256 i = 0; i < claim.tokenIndices.length; ++i) {
            // root
            // - earner leaf 0
            //   - earner 0 address
            //   - earner 0 token root ------+
            // - earner leaf 1               |
            //   - earner 1 address          |
            //   - earner 1 token root       |
            // - earner leaf 2               |
            // ...                           |
            //                               |
            // earner token root <-----------+
            // - token leaf 0
            //   - token 0
            //   - cumulative earnings 0
            // - token leaf 1
            //   - token 1
            //   - cumulative earnings 1
            // - ...
            _verifyTokenClaimProof({
                earnerTokenRoot: claim.earnerLeaf.earnerTokenRoot,
                tokenLeafIndex: claim.tokenIndices[i],
                tokenProof: claim.tokenTreeProofs[i],
                tokenLeaf: claim.tokenLeaves[i]
            });
        }
    }

    function _verifyTokenClaimProof(
        bytes32 earnerTokenRoot,
        uint32 tokenLeafIndex,
        bytes calldata tokenProof,
        TokenTreeMerkleLeaf calldata tokenLeaf
    ) internal pure {
        // Validate index size so that there aren't multiple valid indices for the given proof
        // index can't be greater than 2**(tokenProof/32)
        require(
            tokenLeafIndex < (1 << (tokenProof.length / 32)),
            "RewardsCoordinator._verifyTokenClaim: invalid tokenLeafIndex"
        );

        // Verify inclusion of token leaf
        bytes32 tokenLeafHash = calculateTokenLeafHash(tokenLeaf);
        require(
            Merkle.verifyInclusionKeccak({
                root: earnerTokenRoot,
                index: tokenLeafIndex,
                proof: tokenProof,
                leaf: tokenLeafHash
            }),
            "RewardsCoordinator._verifyTokenClaim: invalid token claim proof"
        );
    }

    function _verifyEarnerClaimProof(
        bytes32 root,
        uint32 earnerLeafIndex,
        bytes calldata earnerProof,
        EarnerTreeMerkleLeaf calldata earnerLeaf
    ) internal pure {
        // Validate index size so that there aren't multiple valid indices for the given proof
        // index can't be greater than 2**(earnerProof/32)
        require(
            earnerLeafIndex < (1 << (earnerProof.length / 32)),
            "RewardsCoordinator._verifyEarnerClaimProof: invalid earnerLeafIndex"
        );
        // Verify inclusion of earner leaf
        bytes32 earnerLeafHash = calculateEarnerLeafHash(earnerLeaf);
        // forgefmt: disable-next-item
        require(
            Merkle.verifyInclusionKeccak({
                root: root,
                index: earnerLeafIndex,
                proof: earnerProof,
                leaf: earnerLeafHash
            }),
            "RewardsCoordinator._verifyEarnerClaimProof: invalid earner claim proof"
        );
    }

    function calculateEarnerLeafHash(EarnerTreeMerkleLeaf calldata leaf) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(EARNER_LEAF_SALT, leaf.earner, leaf.earnerTokenRoot));
    }

    function calculateTokenLeafHash(TokenTreeMerkleLeaf calldata leaf) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(TOKEN_LEAF_SALT, leaf.token, leaf.cumulativeEarnings));
    }
}




library Merkle {
    function verifyInclusionKeccak(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bool) {
        return processInclusionProofKeccak(proof, leaf, index) == root;
    }

    function processInclusionProofKeccak(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bytes32) {
        require(proof.length % 32 == 0, "Merkle.processInclusionProofKeccak: proof length should be a multiple of 32");
        bytes32 computedHash = leaf;
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, mload(add(proof, i)))
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            }
        }
        return computedHash;
    }

    function verifyInclusionSha256(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bool) {
        return processInclusionProofSha256(proof, leaf, index) == root;
    }

    function processInclusionProofSha256(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bytes32) {
        require(
            proof.length != 0 && proof.length % 32 == 0,
            "Merkle.processInclusionProofSha256: proof length should be a non-zero multiple of 32"
        );
        bytes32[1] memory computedHash = [leaf];
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, mload(computedHash))
                    mstore(0x20, mload(add(proof, i)))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, mload(computedHash))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            }
        }
        return computedHash[0];
    }

    function merkleizeSha256(bytes32[] memory leaves) internal pure returns (bytes32) {
        //there are half as many nodes in the layer above the leaves
        uint256 numNodesInLayer = leaves.length / 2;
        //create a layer to store the internal nodes
        bytes32[] memory layer = new bytes32[](numNodesInLayer);
        //fill the layer with the pairwise hashes of the leaves
        for (uint256 i = 0; i < numNodesInLayer; i++) {
            layer[i] = sha256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
        }
        //the next layer above has half as many nodes
        numNodesInLayer /= 2;
        //while we haven't computed the root
        while (numNodesInLayer != 0) {
            //overwrite the first numNodesInLayer nodes in layer with the pairwise hashes of their children
            for (uint256 i = 0; i < numNodesInLayer; i++) {
                layer[i] = sha256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
            //the next layer above has half as many nodes
            numNodesInLayer /= 2;
        }
        //the first node in the layer is the root
        return layer[0];
    }
}
*/
