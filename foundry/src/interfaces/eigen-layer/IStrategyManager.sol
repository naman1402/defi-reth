// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IStrategyManager {
    function stakerStrategyShares(address user, address strategy)
        external
        view
        returns (uint256 shares);
    function depositIntoStrategy(
        address strategy,
        address token,
        uint256 amount
    ) external returns (uint256 shares);
}
