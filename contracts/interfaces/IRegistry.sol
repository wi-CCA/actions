// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IActions.sol";

/// @title IRegistry
/// @notice Interface of `registry`.
/// @author lukepark327@gmail.com
interface IRegistry {
    struct Task {
        bool active;
        address owner;
        IActions target;
        // uint256 value;
        bytes checkData;
        uint256 balance;
        uint256 expiry; // block height
    }

    function register(
        bool active_,
        address owner_,
        IActions target_,
        bytes calldata checkData_,
        uint256 balance_,
        uint256 expiry_
    ) external payable returns (uint256 id);

    function update(
        uint256 id,
        bool active_,
        address owner_,
        bytes calldata checkData_,
        uint256 expiry_
    ) external payable;

    function deposit(uint256 id, uint256 amount) external payable;

    function withdraw(uint256 id, uint256 amount) external;

    function executeTask(uint256 id) external;

    function executeTaskBatch(uint256[] memory ids) external;

    function tryExecuteTaskBatch(uint256[] memory ids) external;

    function checkTask(uint256 id) external view returns (bool);

    function checkTaskBatch(
        uint256[] memory ids
    ) external view returns (bool[] memory);
}
