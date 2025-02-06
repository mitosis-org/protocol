// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IRewardDistributor } from '../../interfaces/hub/reward/IRewardDistributor.sol';
import { ITreasury } from '../../interfaces/hub/reward/ITreasury.sol';
import { StdError } from '../../lib/StdError.sol';
import { TreasuryStorageV1 } from './TreasuryStorageV1.sol';

/**
 * @title Treasury
 * @notice A reward handler that stores rewards for later dispatch
 */
contract Treasury is ITreasury, TreasuryStorageV1, AccessControlEnumerableUpgradeable {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  /// @notice Role for managing treasury (keccak256("TREASURY_MANAGER_ROLE"))
  bytes32 public constant TREASURY_MANAGER_ROLE = 0xede9dcdb0ce99dc7cec9c7be9246ad08b37853683ad91569c187b647ddf5e21c;
  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address admin) external initializer {
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(TREASURY_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(DISPATCHER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @inheritdoc ITreasury
   */
  function storeRewards(address matrixVault, address reward, uint256 amount) external onlyRole(TREASURY_MANAGER_ROLE) {
    _storeRewards(matrixVault, reward, amount);
  }

  /**
   * @inheritdoc ITreasury
   */
  function dispatch(address matrixVault, address reward, uint256 amount, address distributor)
    external
    onlyRole(DISPATCHER_ROLE)
  {
    StorageV1 storage $ = _getStorageV1();

    uint256 balance = _balances($, matrixVault, reward);
    require(balance >= amount, ITreasury__InsufficientBalance()); // TODO(eddy): custom error

    $.balances[matrixVault][reward] = balance - amount;
    $.history[matrixVault][reward].push(
      Log({
        timestamp: block.timestamp.toUint48(),
        amount: amount.toUint208(),
        sign: false // withdrawal
       })
    );

    IERC20(reward).forceApprove(distributor, amount);
    IRewardDistributor(distributor).handleReward(matrixVault, reward, amount);

    emit RewardDispatched(matrixVault, reward, distributor, amount);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _storeRewards(address matrixVault, address reward, uint256 amount) internal {
    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);

    StorageV1 storage $ = _getStorageV1();

    $.balances[matrixVault][reward] += amount;
    $.history[matrixVault][reward].push(
      Log({
        timestamp: block.timestamp.toUint48(),
        amount: amount.toUint208(),
        sign: true // deposit
       })
    );

    emit RewardStored(matrixVault, reward, _msgSender(), amount);
  }
}
