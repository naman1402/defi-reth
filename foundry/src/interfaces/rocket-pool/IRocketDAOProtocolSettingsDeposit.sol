// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8;

interface IRocketDAOProtocolSettingsDeposit {
    function getDepositEnabled() external view returns (bool);
    function getAssignDepositsEnabled() external view returns (bool);
    function getMinimumDeposit() external view returns (uint256);
    function getMaximumDepositPoolSize() external view returns (uint256);
    function getMaximumDepositAssignments() external view returns (uint256);
    function getMaximumDepositSocialisedAssignments()
        external
        view
        returns (uint256);
    function getDepositFee() external view returns (uint256);
}
