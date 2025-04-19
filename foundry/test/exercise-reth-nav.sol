// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {RETH} from "@src/Constants.sol";
import {RethNav} from "@src/exercises/RethNav.sol";

// forge test --fork-url $FORK_URL --match-path test/exercise-reth-nav.sol -vv

contract RethNavTest is Test {
    IRETH reth = IRETH(RETH);
    RethNav nav;

    function setUp() public {
        nav = new RethNav();
    }

    function test_nav() public view {
        // amount of ETH backing 1 rETH
        uint256 navRate = nav.getExchangeRate();
        console.log("ETH / rETH rate from Rocket Pool: %e", navRate);
        assertGt(navRate, 0);

        uint256 chainlinkRate = nav.getExchangeRateFromChainlink();
        console.log("ETH / rETH rate from Chainlink: %e", chainlinkRate);
        assertGt(chainlinkRate, 0);
    }
}
