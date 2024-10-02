// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { ITWABSnapshots } from '../interfaces/twab/ITWABSnapshots.sol';
import { StdError } from '../lib/StdError.sol';
import { TWABCheckpoints } from '../lib/TWABCheckpoints.sol';
import { TWABSnapshotsStorageV1 } from './TWABSnapshotsStorageV1.sol';

abstract contract TWABSnapshots is
  ITWABSnapshots,
  ContextUpgradeable,
  EIP712Upgradeable,
  NoncesUpgradeable,
  TWABSnapshotsStorageV1
{
  using SafeCast for uint256;
  using Checkpoints for Checkpoints.Trace208;
  using TWABCheckpoints for TWABCheckpoints.Trace;

  bytes32 private constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  // ================== NOTE: Initializer ================== //

  function __TWABSnapshots_init(address delegationRegistry_) internal {
    __EIP712_init_unchained('TWABSnapshots', '1');
    __Nonces_init_unchained();
    __Context_init_unchained();

    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    $.delegationRegistry = IDelegationRegistry(delegationRegistry_);
  }

  // ================== NOTE: Clock implementation ================ //

  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  function clock() public view virtual override(IERC6372, TWABSnapshotsStorageV1) returns (uint48) {
    return Time.timestamp();
  }

  // ================== NOTE: ERC5805 View Functions ================== //

  function delegates(address account) external view returns (address) {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();
    (address delegates_,) = _delegateeOf($, account);
    return delegates_;
  }

  function getVotes(address account) external view returns (uint256) {
    (uint208 amount,,) = _getTWABSnapshotsStorageV1().delegateCheckpoints[account].latest();
    return uint256(amount);
  }

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    (uint208 amount,,) = _delegationSnapshot(_getTWABSnapshotsStorageV1(), account, timepoint);
    return uint256(amount);
  }

  function getPastTotalSupply(uint256 timepoint) external view virtual returns (uint256 balance) {
    (uint208 amount,,) = _totalSupplySnapshot(_getTWABSnapshotsStorageV1(), timepoint);
    return uint256(amount);
  }

  // ================== NOTE: View Functions ================== //

  function delegationRegistry() external view returns (IDelegationRegistry) {
    return _getTWABSnapshotsStorageV1().delegationRegistry;
  }

  function totalSupplySnapshot() external view virtual returns (uint208 balance, uint256 twab, uint48 position) {
    return _getTWABSnapshotsStorageV1().totalCheckpoints.latest();
  }

  function totalSupplySnapshot(uint256 timepoint)
    external
    view
    virtual
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _totalSupplySnapshot(_getTWABSnapshotsStorageV1(), timepoint);
  }

  function balanceSnapshot(address account, uint256 timepoint) external view virtual returns (uint208 balance) {
    return _balanceSnapshot(_getTWABSnapshotsStorageV1(), account, timepoint);
  }

  function delegateSnapshot(address account)
    external
    view
    virtual
    override
    returns (uint208 balnace, uint256 twab, uint48 position)
  {
    return _getTWABSnapshotsStorageV1().delegateCheckpoints[account].latest();
  }

  function delegateSnapshot(address account, uint256 timestamp)
    external
    view
    virtual
    override
    returns (uint208 balance, uint256 twab, uint48 position)
  {
    return _delegationSnapshot(_getTWABSnapshotsStorageV1(), account, timestamp);
  }

  // ================== NOTE: Mutative Functions ================== //

  function delegate(address delegatee) external {
    address account = _msgSender();
    _delegate(_getTWABSnapshotsStorageV1(), account, delegatee);
  }

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
    require(clock() <= expiry, VotesExpiredSignature(expiry));

    address signer =
      ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))), v, r, s);
    _useCheckedNonce(signer, nonce);
    _delegate(_getTWABSnapshotsStorageV1(), signer, delegatee);
  }

  function delegateByManager(address account, address delegatee) external {
    TWABSnapshotsStorageV1_ storage $ = _getTWABSnapshotsStorageV1();

    address delegationManager = $.delegationRegistry.delegationManager(account);
    require(delegationManager == _msgSender(), StdError.Unauthorized());

    _delegate($, account, delegatee);
  }

  // ================== NOTE: Internal Functions ================== //

  enum DelegateeOfResult {
    None,
    DefaultDelegatee,
    NonDefaultDelegatee
  }

  function _delegateeOf(TWABSnapshotsStorageV1_ storage $, address account)
    internal
    view
    returns (address delegatee_, DelegateeOfResult result)
  {
    delegatee_ = $.delegates[account];
    if (delegatee_ != address(0)) return (delegatee_, DelegateeOfResult.None);

    address defaultDelegatee = $.delegationRegistry.defaultDelegatee(account);
    if (defaultDelegatee != address(0)) return (defaultDelegatee, DelegateeOfResult.DefaultDelegatee);
    else return (account, DelegateeOfResult.NonDefaultDelegatee);
  }

  function _snapshotBalance(TWABSnapshotsStorageV1_ storage $, address from, address to) internal {
    if (from == address(0) || to == address(0)) _push($.totalCheckpoints, _replace, _getTotalSupply().toUint208());

    uint48 currentTimestamp = clock();
    if (from != address(0)) $.balanceCheckpoints[from].push(currentTimestamp, _getBalance(from).toUint208());
    if (to != address(0)) $.balanceCheckpoints[to].push(currentTimestamp, _getBalance(to).toUint208());
  }

  function _delegate(TWABSnapshotsStorageV1_ storage $, address account, address delegatee) internal {
    require(delegatee != address(0), StdError.InvalidAddress('delegatee'));

    (address oldDelegatee,) = _delegateeOf($, account);
    $.delegates[account] = delegatee;

    emit DelegateChanged(account, oldDelegatee, delegatee);

    (uint208 balance,,) = _delegationSnapshot($, account, clock());
    _snapshotDelegateInner($, oldDelegatee, delegatee, balance);
  }

  function _snapshotDelegate(TWABSnapshotsStorageV1_ storage $, address from, address to, uint256 amount) internal {
    (address toDelegatee, DelegateeOfResult result) = _delegateeOf($, to);
    if (result == DelegateeOfResult.DefaultDelegatee) _delegate($, to, toDelegatee);
    if (result == DelegateeOfResult.NonDefaultDelegatee) $.delegates[to] = toDelegatee;

    _snapshotDelegateInner($, $.delegates[from], toDelegatee, amount);
  }

  function _snapshotDelegateInner(TWABSnapshotsStorageV1_ storage $, address from, address to, uint256 amount) private {
    if (from != to && amount > 0) {
      if (from != address(0)) {
        (uint256 oldValue, uint256 newValue,,) = _push($.delegateCheckpoints[from], _unsafeSub, amount.toUint208());
        emit DelegateVotesChanged(from, oldValue, newValue);
      }

      if (to != address(0)) {
        (uint256 oldValue, uint256 newValue,,) = _push($.delegateCheckpoints[to], _unsafeAdd, amount.toUint208());
        emit DelegateVotesChanged(to, oldValue, newValue);
      }
    }
  }

  function _push(
    TWABCheckpoints.Trace storage store,
    function(uint208, uint208) view returns (uint208) op,
    uint208 delta
  ) internal virtual returns (uint208 lastBalance_, uint208 currentBalance_, uint256 lastTWAB_, uint256 currentTWAB_) {
    (uint208 lastBalance, uint256 lastTWAB, uint48 lastPosition) = store.latest();

    uint208 balance = op(lastBalance, delta);

    uint256 twab = lastTWAB;
    uint48 timestamp = clock();
    // TWAB is a cumulative value, so it is not affected by the current balance.
    if (timestamp > lastPosition) {
      twab = _calcAccumulatedTWAB(lastTWAB, lastBalance, timestamp - lastPosition);
    }

    return TWABCheckpoints.push(store, timestamp, balance, twab);
  }

  function _calcAccumulatedTWAB(uint256 lastTWAB, uint208 lastBalance, uint48 duration) internal pure returns (uint256) {
    return lastTWAB + (lastBalance * duration);
  }

  function _replace(uint208, uint208 to) private pure returns (uint208) {
    return to;
  }

  function _unsafeAdd(uint208 a, uint208 b) private pure returns (uint208) {
    unchecked {
      return a + b;
    }
  }

  function _unsafeSub(uint208 a, uint208 b) private pure returns (uint208) {
    unchecked {
      return a - b;
    }
  }

  /**
   * @dev Must return the total units held by an account.
   */
  function _getTotalSupply() internal view virtual returns (uint256);

  /**
   * @dev Must return the balance units held by an account.
   */
  function _getBalance(address) internal view virtual returns (uint256);
}
