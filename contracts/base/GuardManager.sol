// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../common/Enum.sol";
import "../common/SelfAuthorized.sol";
import "../interfaces/IERC165.sol";

interface Guard is IERC165 {
    /// @dev Checks if a transaction should be allowed.
    /// @param to The address of the recipient.
    /// @param value The value of the transaction.
    /// @param data The data of the transaction.
    /// @param operation The operation type. 0 - CALL, 1 - DELEGATECALL
    /// @param safeTxGas The gas limit for the transaction.
    /// @param baseGas The base gas limit for the transaction.
    /// @param gasPrice The gas price for the transaction.
    /// @param gasToken The token used for paying gas.
    /// @param refundReceiver The address that will receive the gas fees refund.
    /// @param signatures The signatures of the transaction.
    /// @param msgSender The sender of the message that triggered the transaction.
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external;

    /// @dev Checks if a module transaction should be allowed.
    /// @param to The address of the recipient.
    /// @param value The value of the transaction.
    /// @param data The data of the transaction.
    /// @param operation The operation type.
    /// @param module The module that triggered the transaction.
    function checkModuleTransaction(address to, uint256 value, bytes memory data, Enum.Operation operation, address module) external;

    /// @dev Checks if a transaction was successful after execution.
    /// @param hash The hash of the transaction that was executed.
    ///        In a module transaction, hash of the transaction call data.
    /// @param success Whether or not the transaction was successful.
    function checkAfterExecution(bytes32 hash, bool success) external;
}

abstract contract BaseGuard is Guard {
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(Guard).interfaceId || // 0x945b8148
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}

/**
 * @title Guard Manager - A contract managing transaction guards which perform pre and post-checks on Safe transactions.
 * @author Richard Meissner - @rmeissner
 */
abstract contract GuardManager is SelfAuthorized {
    event ChangedGuard(address indexed guard);

    // keccak256("guard_manager.guard.address")
    bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    /**
     * @dev Set a guard that checks transactions before execution
     *      This can only be done via a Safe transaction.
     *      ⚠️ IMPORTANT: Since a guard has full power to block Safe transaction execution,
     *        a broken guard can cause a denial of service for the Safe. Make sure to carefully
     *        audit the guard code and design recovery mechanisms.
     * @notice Set Transaction Guard `guard` for the Safe. Make sure you trust the guard.
     * @param guard The address of the guard to be used or the 0 address to disable the guard
     */
    function setGuard(address guard) external authorized {
        if (guard != address(0)) {
            require(Guard(guard).supportsInterface(type(Guard).interfaceId), "GS300");
        }
        bytes32 slot = GUARD_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        /// @solidity memory-safe-assembly
        assembly {
            sstore(slot, guard)
        }
        emit ChangedGuard(guard);
    }

    /**
     * @dev Internal method to retrieve the current guard
     *      We do not have a public method because we're short on bytecode size limit,
     *      to retrieve the guard address, one can use `getStorageAt` from `StorageAccessible` contract
     *      with the slot `GUARD_STORAGE_SLOT`
     * @return guard The address of the guard
     */
    function getGuard() internal view returns (address guard) {
        bytes32 slot = GUARD_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        /// @solidity memory-safe-assembly
        assembly {
            guard := sload(slot)
        }
    }
}
