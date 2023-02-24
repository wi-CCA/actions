// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IActions.sol";
import "./interfaces/IRegistry.sol";

/// @title IRegistry
/// @notice Interface of `registry`.
/// @author lukepark327@gmail.com
contract Registry is IRegistry, Context {
    using SafeERC20 for IERC20;

    IERC20 public feeToken; // address(0) for native asset
    uint256 public fee;

    mapping(uint256 => Task) public tasks;
    uint256 internal _id = 1;

    constructor(address feeToken_, uint256 fee_) {
        // if (feeToken_ != address(0)) {
        feeToken = IERC20(feeToken_);
        // }
        fee = fee_;
    }

    function register(
        bool active_,
        address owner_,
        IActions target_,
        bytes calldata checkData_,
        uint256 balance_,
        uint256 expiry_
    ) external payable virtual returns (uint256 id) {
        address _msgSender = _msgSender();

        if (address(feeToken) == address(0)) {
            require(
                msg.value == balance_,
                "IRegistry::register: Not enough value."
            );
        } else {
            feeToken.safeTransferFrom(_msgSender, address(this), balance_);
        }
        require(balance_ >= fee, "IRegistry::register: Minimum value.");

        require(expiry_ > block.number, "IRegistry::register: Invalid expiry.");
        tasks[_id++] = Task(
            active_,
            owner_,
            target_,
            checkData_,
            balance_,
            expiry_
        );
        return _id;
    }

    function update(
        uint256 id,
        bool active_,
        address owner_,
        bytes calldata checkData_,
        uint256 expiry_
    ) external payable virtual {
        Task storage task = tasks[id];
        address _msgSender = _msgSender();
        require(_msgSender == task.owner, "IRegistry::update: Invalid owner.");

        require(expiry_ > block.number, "IRegistry::update: Invalid expiry.");
        task.active = active_;
        task.owner = owner_;
        task.checkData = checkData_;
        task.expiry = expiry_;
    }

    function deposit(uint256 id, uint256 amount) external payable virtual {
        Task storage task = tasks[id];
        // require(_msgSender == task.owner, "IRegistry::deposit: Invalid owner.");

        if (address(feeToken) == address(0)) {
            require(
                msg.value == amount,
                "IRegistry::deposit: Not enough value."
            );
        } else {
            feeToken.safeTransferFrom(_msgSender(), address(this), amount);
        }

        task.balance += amount;
        require(task.balance >= fee, "IRegistry::deposit: Minimum value.");
    }

    function withdraw(uint256 id, uint256 amount) external virtual {
        Task storage task = tasks[id];
        require(
            _msgSender() == task.owner,
            "IRegistry::withdraw: Invalid owner."
        );

        require(
            address(this).balance >= amount,
            "IRegistry::withdraw: Insufficient balance."
        );

        if (address(feeToken) == address(0)) {
            (bool success, ) = task.owner.call{value: amount}("");
            require(success, "IRegistry::withdraw: Unable to send value.");
        } else {
            feeToken.safeTransfer(task.owner, amount);
        }

        task.balance -= amount;
    }

    function executeTask(uint256 id) external virtual {
        Task storage task = tasks[id];

        (bool upkeepNeeded, bytes memory performData) = task.target.checkUpkeep(
            task.checkData
        );
        if (upkeepNeeded) {
            // try task.target.performUpkeep(performData) {} catch {}
            task.target.performUpkeep(performData);

            if (address(feeToken) == address(0)) {
                (bool success, ) = _msgSender().call{value: fee}("");
                require(success, "IRegistry::withdraw: Unable to send value.");
            } else {
                feeToken.safeTransfer(_msgSender(), fee);
            }

            task.balance -= fee;
        }
    }

    function executeTaskBatch(uint256[] memory ids) external virtual {
        uint256 totalFee = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            Task storage task = tasks[ids[i]];

            (bool upkeepNeeded, bytes memory performData) = task
                .target
                .checkUpkeep(task.checkData);
            if (upkeepNeeded) {
                task.target.performUpkeep(performData);
                task.balance -= fee;
                totalFee += fee;
            }
        }

        if (totalFee != 0) {
            if (address(feeToken) == address(0)) {
                (bool success, ) = _msgSender().call{value: totalFee}("");
                require(success, "IRegistry::withdraw: Unable to send value.");
            } else {
                feeToken.safeTransfer(_msgSender(), totalFee);
            }
        }
    }

    function tryExecuteTaskBatch(uint256[] memory ids) external virtual {
        uint256 totalFee = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            Task storage task = tasks[ids[i]];

            (bool upkeepNeeded, bytes memory performData) = task
                .target
                .checkUpkeep(task.checkData);
            if (upkeepNeeded) {
                try task.target.performUpkeep(performData) {
                    task.balance -= fee;
                    totalFee += fee;
                } catch {}
            }
        }

        if (totalFee != 0) {
            if (address(feeToken) == address(0)) {
                (bool success, ) = _msgSender().call{value: totalFee}("");
                require(success, "IRegistry::withdraw: Unable to send value.");
            } else {
                feeToken.safeTransfer(_msgSender(), totalFee);
            }
        }
    }

    function checkTask(uint256 id) public view virtual returns (bool) {
        Task storage task = tasks[id];
        (bool upkeepNeeded, ) = task.target.checkUpkeep(task.checkData);
        return upkeepNeeded && task.active && (task.expiry < block.number);
    }

    function checkTaskBatch(
        uint256[] memory ids
    ) public view virtual returns (bool[] memory) {
        bool[] memory upkeepNeededs = new bool[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            Task storage task = tasks[ids[i]];
            (bool upkeepNeeded, ) = task.target.checkUpkeep(task.checkData);
            upkeepNeededs[i] =
                upkeepNeeded &&
                task.active &&
                (task.expiry < block.number);
        }
        return upkeepNeededs;
    }
}
