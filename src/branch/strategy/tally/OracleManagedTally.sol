// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { AccessControlEnumerable } from '@oz/access/extensions/AccessControlEnumerable.sol';
import { Math } from '@oz/utils/math/Math.sol';
import { Pausable } from '@oz/utils/Pausable.sol';

import { StdTally } from './StdTally.sol';

abstract contract OracleManagedTally is StdTally, AccessControlEnumerable, Pausable {
  struct OracleFeed {
    uint256 reportedTotalBalance;
    uint256 reportedPendingDepositBalance;
    uint256 reportedPendingWithdrawBalance;
    uint256 lastUpdatedBlock;
  }

  error OracleManagedTally__AlreadyFed(uint256 blockNumber);

  event OracleFeedUpdated(uint256 totalBalance, uint256 pendingDepositBalance, uint256 pendingWithdrawBalance);

  /// @notice keccak256('mitosis.role.OracleTally.oracle')
  bytes32 public constant ORACLE_ROLE = 0xdb6af33022b6eb75115bfe118916016a510a3f87734665ccd940367c2f0e048e;

  OracleFeed private _oracleFeed;

  constructor(address admin) {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function oracleFeed() external view returns (OracleFeed memory) {
    return _oracleFeed;
  }

  function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }

  function updateOracleFeed(
    uint256 newTotalBalance,
    uint256 newPendingDepositBalance,
    uint256 newPendingWithdrawBalance
  ) external onlyRole(ORACLE_ROLE) whenNotPaused {
    // prevent duplicated feed in the same block
    require(block.number > _oracleFeed.lastUpdatedBlock, OracleManagedTally__AlreadyFed(block.number));

    // update feed
    _oracleFeed.lastUpdatedBlock = block.number;
    _oracleFeed.reportedTotalBalance = newTotalBalance;
    _oracleFeed.reportedPendingDepositBalance = newPendingDepositBalance;
    _oracleFeed.reportedPendingWithdrawBalance = newPendingWithdrawBalance;

    emit OracleFeedUpdated(newTotalBalance, newPendingDepositBalance, newPendingWithdrawBalance);
  }

  function _totalBalance(bytes memory) internal view virtual override returns (uint256) {
    return _oracleFeed.reportedTotalBalance;
  }

  function _pendingDepositBalance(bytes memory) internal view virtual override returns (uint256) {
    return _oracleFeed.reportedPendingDepositBalance;
  }

  function _pendingWithdrawBalance(bytes memory) internal view virtual override returns (uint256) {
    return _oracleFeed.reportedPendingWithdrawBalance;
  }
}
