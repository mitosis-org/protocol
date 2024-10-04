// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IRewardHandler } from '../../interfaces/hub/reward/IRewardHandler.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { BaseHandler } from './BaseHandler.sol';
import { TreasuryStorageV1 } from './TreasuryStorageV1.sol';

/**
 * @title Treasury
 * @notice A reward handler that stores rewards for later dispatch
 */
contract Treasury is BaseHandler, ITreasury, TreasuryStorageV1, AccessControlEnumerableUpgradeable {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  /// @notice Role for managing treasury (keccak256("TREASURY_MANAGER_ROLE"))
  bytes32 public constant TREASURY_MANAGER_ROLE = 0xede9dcdb0ce99dc7cec9c7be9246ad08b37853683ad91569c187b647ddf5e21c;

  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() BaseHandler(HandlerType.Endpoint, DistributionType.Unspecified, 'Treasury Reward Handler') {
    _disableInitializers();
  }

  function initialize(address admin) external initializer {
    __BaseHandler_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(TREASURY_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(DISPATCHER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @inheritdoc ITreasury
   */
  function dispatch(address eolVault, address reward, uint256 amount, address handler, bytes calldata metadata)
    external
    onlyRole(TREASURY_MANAGER_ROLE)
  {
    StorageV1 storage $ = _getStorageV1();

    uint256 balance = _balances($, eolVault, reward);
    require(balance >= amount, ITreasury__InsufficientBalance()); // TODO(eddy): custom error

    $.balances[eolVault][reward] = balance - amount;
    $.history[eolVault][reward].push(
      Log({
        timestamp: IERC6372(eolVault).clock(),
        amount: amount.toUint208(),
        sign: false // withdrawal
       })
    );

    IERC20(reward).forceApprove(handler, amount);
    IRewardHandler(handler).handleReward(eolVault, reward, amount, metadata);

    emit RewardDispatched(eolVault, reward, handler, amount);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  /**
   * @inheritdoc BaseHandler
   */
  function _isDispatchable(address dispatcher) internal view override returns (bool) {
    return hasRole(DISPATCHER_ROLE, dispatcher);
  }

  /**
   * @inheritdoc BaseHandler
   */
  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata) internal override {
    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);

    StorageV1 storage $ = _getStorageV1();

    $.balances[eolVault][reward] += amount;
    $.history[eolVault][reward].push(
      Log({
        timestamp: IERC6372(eolVault).clock(),
        amount: amount.toUint208(),
        sign: true // deposit
       })
    );

    emit RewardHandled(eolVault, reward, _msgSender(), amount);
  }
}
