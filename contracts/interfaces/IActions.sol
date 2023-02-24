// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IActions
/// @notice Interface of `actions`.
/// @dev Compatible with Chainlink Automation.
/// @author lukepark327@gmail.com
interface IActions {
    /* Chainlink-compatible */

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}
