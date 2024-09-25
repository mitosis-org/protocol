// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IVoteManager } from '../interfaces/hub/core/IVoteManager.sol';
import { IERC5805TWAB } from '../interfaces/twab/IERC5805TWAB.sol';
import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { ERC20TWABSnapshots } from './ERC20TWABSnapshots.sol';
import { ERC20TWABSnapshotsWithVoteStorageV1 } from './ERC20TWABSnapshotsWithVoteStorageV1.sol';

abstract contract ERC20TWABSnapshotsWithVote is
  ERC20TWABSnapshots,
  ERC20TWABSnapshotsWithVoteStorageV1,
  EIP712Upgradeable,
  NoncesUpgradeable,
  IERC5805TWAB
{
  using TWABCheckpoints for TWABCheckpoints.Trace;

  bytes32 private constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  // ================== NOTE: Initializer ================== //

  function __ERC20TWABSnapshotsWithVote_init(IVoteManager voteManager, string memory name_, string memory symbol_)
    internal
  {
    __ERC20_init_unchained(name_, symbol_);
    __EIP712_init_unchained(name_, '1');
    __Nonces_init_unchained();

    StorageV1 storage $ = _getStorageV1();

    $.voteManager = IVoteManager(voteManager);
  }

  // ================== NOTE: View Functions ================== //

  function delegates(address account) external view returns (address) {
    address delegates_ = _getStorageV1().delegates[account];
    return delegates_ == address(0) ? account : delegates_;
  }

  function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
    (uint208 total,,) = getPastTotalSnapshot(timepoint);
    return uint256(total);
  }

  function getVotes(address account) external view returns (uint256) {
    (uint208 vote,,) = _getStorageV1().delegateCheckpoints[account].latest();
    return uint256(vote);
  }

  function getVoteSnapshot(address account) external view returns (uint208 balance, uint256 twab, uint48 position) {
    return _getStorageV1().delegateCheckpoints[account].latest();
  }

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    (uint208 vote,,) = _getPastVoteSnapshot(_getStorageV1(), account, timepoint);
    return uint256(vote);
  }

  function getPastVoteSnapshot(address account, uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _getPastVoteSnapshot(_getStorageV1(), account, timepoint);
  }

  // ================== NOTE: Mutative Functions ================== //

  function delegate(address delegatee) external {
    address account = _msgSender();
    _delegate(_getStorageV1(), account, delegatee);
  }

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
    if (block.timestamp > expiry) revert VotesExpiredSignature(expiry);

    address signer =
      ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s);
    _useCheckedNonce(signer, nonce);
    _delegate(_getStorageV1(), signer, delegatee);
  }

  function delegateByManager(address account, address delegatee) external {
    StorageV1 storage $ = _getStorageV1();

    address delegationManager = $.voteManager.delegationManager(account);
    if (delegationManager != _msgSender()) revert StdError.Unauthorized();

    _delegate($, account, delegatee);
  }

  // ================== NOTE: Internal Functions ================== //

  function _delegate(StorageV1 storage $, address account, address delegatee) internal {
    address oldDelegate = $.delegates[account];
    $.delegates[account] = delegatee;

    emit DelegateChanged(account, oldDelegate, delegatee);
    _moveDelegateVotes($, oldDelegate, delegatee, _getVotingUnits(account));
  }

  function _update(address from, address to, uint256 value) internal override {
    super._update(from, to, value);

    StorageV1 storage $ = _getStorageV1();

    address toDelegatee = $.delegates[to];
    if (toDelegatee == address(0)) {
      address defaultDelegatee = $.voteManager.defaultDelegatee(to);
      if (defaultDelegatee != address(0)) _delegate($, to, defaultDelegatee);
      else $.delegates[to] = to;
    }

    _moveDelegateVotes($, $.delegates[from], $.delegates[to], value);
  }

  function _getPastVoteSnapshot(StorageV1 storage $, address account, uint256 timepoint)
    internal
    view
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    uint48 currentTimestamp = clock();
    require(timepoint < currentTimestamp, ERC5805FutureLookup(timepoint, currentTimestamp));
    return $.delegateCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  /**
   * @dev Moves delegated votes from one delegate to another.
   */
  function _moveDelegateVotes(StorageV1 storage $, address from, address to, uint256 amount) private {
    if (from != to && amount > 0) {
      if (from != address(0)) {
        (uint256 oldValue, uint256 newValue,,) = _push($.delegateCheckpoints[from], _sub, SafeCast.toUint208(amount));
        emit DelegateVotesChanged(from, oldValue, newValue);
      }
      if (to != address(0)) {
        (uint256 oldValue, uint256 newValue,,) = _push($.delegateCheckpoints[to], _add, SafeCast.toUint208(amount));
        emit DelegateVotesChanged(to, oldValue, newValue);
      }
    }
  }

  /**
   * @dev Must return the voting units held by an account.
   */
  function _getVotingUnits(address) internal view virtual returns (uint256);
}
