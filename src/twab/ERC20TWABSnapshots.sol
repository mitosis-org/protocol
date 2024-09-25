// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { IERC5805TWAB } from '../interfaces/twab/IERC5805TWAB.sol';
import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { TWABSnapshots } from './TWABSnapshots.sol';

abstract contract ERC20TWABSnapshots is
  ERC20Upgradeable,
  EIP712Upgradeable,
  NoncesUpgradeable,
  IERC5805TWAB,
  TWABSnapshots
{
  using TWABCheckpoints for TWABCheckpoints.Trace;

  /**
   * @dev Total supply cap has been exceeded, introducing a risk of votes overflowing.
   */
  error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

  bytes32 private constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  // ================== NOTE: Initializer ================== //

  function __ERC20TWABSnapshots_init(address delegationRegistry_, string memory name_, string memory symbol_) internal {
    __ERC20_init_unchained(name_, symbol_);
    __EIP712_init_unchained(name_, '1');
    __Nonces_init_unchained();

    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    $.delegationRegistry = IDelegationRegistry(delegationRegistry_);
  }

  // ================== NOTE: View Functions ================== //

  function delegates(address account) external view returns (address) {
    address delegates_ = _getTWABSnapshotsStorageV1().delegates[account];
    return delegates_ == address(0) ? account : delegates_;
  }

  function delegationRegistry() external view returns (IDelegationRegistry) {
    return _getTWABSnapshotsStorageV1().delegationRegistry;
  }

  function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
    (uint208 total,,) = getPastTotalSnapshot(timepoint);
    return uint256(total);
  }

  function getVotes(address account) external view returns (uint256) {
    (uint208 vote,,) = _getTWABSnapshotsStorageV1().delegateCheckpoints[account].latest();
    return uint256(vote);
  }

  function getVoteSnapshot(address account) external view returns (uint208 balance, uint256 twab, uint48 position) {
    return _getTWABSnapshotsStorageV1().delegateCheckpoints[account].latest();
  }

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    (uint208 vote,,) = _getPastVoteSnapshot(_getTWABSnapshotsStorageV1(), account, timepoint);
    return uint256(vote);
  }

  function getPastVoteSnapshot(address account, uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _getPastVoteSnapshot(_getTWABSnapshotsStorageV1(), account, timepoint);
  }

  // ================== NOTE: Mutative Functions ================== //

  function delegate(address delegatee) external {
    address account = _msgSender();
    _delegate(_getTWABSnapshotsStorageV1(), account, delegatee);
  }

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
    if (block.timestamp > expiry) revert VotesExpiredSignature(expiry);

    address signer =
      ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s);
    _useCheckedNonce(signer, nonce);
    _delegate(_getTWABSnapshotsStorageV1(), signer, delegatee);
  }

  function delegateByManager(address account, address delegatee) external {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    address delegationManager = $.delegationRegistry.delegationManager(account);
    if (delegationManager != _msgSender()) revert StdError.Unauthorized();

    _delegate($, account, delegatee);
  }

  // ================== NOTE: Internal Functions ================== //

  function _delegate(TWABSnapshotsStorageV1_ storage $, address account, address delegatee) internal {
    address oldDelegate = $.delegates[account];
    $.delegates[account] = delegatee;

    emit DelegateChanged(account, oldDelegate, delegatee);
    _moveDelegateVotes($, oldDelegate, delegatee, _getVotingUnits(account));
  }

  function _getPastVoteSnapshot(TWABSnapshotsStorageV1_ storage $, address account, uint256 timepoint)
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
  function _moveDelegateVotes(TWABSnapshotsStorageV1_ storage $, address from, address to, uint256 amount) private {
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

  function _maxSupply() internal view virtual returns (uint256) {
    return type(uint208).max;
  }

  function _update(address from, address to, uint256 value) internal virtual override {
    super._update(from, to, value);
    if (from == address(0)) {
      uint256 supply = totalSupply();
      uint256 cap = _maxSupply();
      require(supply <= cap, ERC20ExceededSafeSupply(supply, cap));
    }
    _snapshot(from, to, value);

    // Update delegate votes
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    address toDelegatee = $.delegates[to];
    if (toDelegatee == address(0)) {
      address defaultDelegatee = $.delegationRegistry.defaultDelegatee(to);
      if (defaultDelegatee != address(0)) {
        _delegate($, to, defaultDelegatee);
      } else {
        toDelegatee = to;
        $.delegates[to] = to;
      }
    }

    _moveDelegateVotes($, $.delegates[from], toDelegatee, value);
  }

  /**
   * @dev Must return the voting units held by an account.
   */
  function _getVotingUnits(address) internal view virtual returns (uint256);
}
