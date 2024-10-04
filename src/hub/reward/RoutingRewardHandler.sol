// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IRewardHandler } from '../../interfaces/hub/reward/IRewardHandler.sol';
import { IRoutingRewardHandler } from '../../interfaces/hub/reward/IRoutingRewardHandler.sol';
import { StdError } from '../../lib/StdError.sol';
import { BaseHandler } from './BaseHandler.sol';
import { RoutingRewardHandlerStorageV1 } from './RoutingRewardHandlerStorageV1.sol';

/**
 * @title RoutingRewardHandler
 * @notice A reward handler that routes rewards to the other handlers
 */
contract RoutingRewardHandler is
  BaseHandler,
  IRoutingRewardHandler,
  RoutingRewardHandlerStorageV1,
  AccessControlEnumerableUpgradeable
{
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @notice Role for managing handlers (keccak256("HANDLER_MANAGER_ROLE"))
  bytes32 public constant HANDLER_MANAGER_ROLE = 0x20dd55fec661d8d0e6e8d90d1217e64ba3caa824cad065d0f9a1591e4a42d55f;

  /// @notice Role for dispatching rewards (keccak256("DISPATCHER_ROLE"))
  bytes32 public constant DISPATCHER_ROLE = 0xfbd38eecf51668fdbc772b204dc63dd28c3a3cf32e3025f52a80aa807359f50c;

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() BaseHandler(HandlerType.Middleware, DistributionType.Unspecified, 'Routing Reward Handler') {
    _disableInitializers();
  }

  function initialize(address admin) external initializer {
    __BaseHandler_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(HANDLER_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(DISPATCHER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  /**
   * @inheritdoc IRoutingRewardHandler
   */
  function setHandlerConfig(address eolVault, address reward, IRewardHandler handler)
    external
    onlyRole(HANDLER_MANAGER_ROLE)
  {
    _setHandlerConfig(_getStorageV1(), eolVault, reward, handler);
  }

  /**
   * @inheritdoc IRoutingRewardHandler
   */
  function setHandlerConfig(address eolVault, address reward, DistributionType distributionType_)
    external
    onlyRole(HANDLER_MANAGER_ROLE)
  {
    _setHandlerConfig(_getStorageV1(), eolVault, reward, distributionType_);
  }

  /**
   * @inheritdoc IRoutingRewardHandler
   */
  function setDefaultHandler(DistributionType distributionType_, IRewardHandler defaultHandler_)
    external
    onlyRole(HANDLER_MANAGER_ROLE)
  {
    _setDefaultHandler(_getStorageV1(), distributionType_, defaultHandler_);
  }

  /**
   * @inheritdoc IRoutingRewardHandler
   */
  function registerHandler(IRewardHandler handler_) external onlyRole(HANDLER_MANAGER_ROLE) {
    _registerHandler(_getStorageV1(), handler_);
  }

  /**
   * @inheritdoc IRoutingRewardHandler
   */
  function unregisterHandler(IRewardHandler handler_) external onlyRole(HANDLER_MANAGER_ROLE) {
    _unregisterHandler(_getStorageV1(), handler_);
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
   * @dev This method can only be called by the Dispatcher
   * @dev If metadata is not provided, the stored handler will be used.
   * @dev If not empty, handler will be determined by the metadata type (the first byte) and also its usage
   */
  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) internal override {
    StorageV1 storage $ = _getStorageV1();

    IRewardHandler handler;
    bytes memory metadata_;

    if (metadata.length == 0) {
      // If metadata is not provided, use the stored handler
      handler = _route($, eolVault, reward);
      metadata_ = '';
    } else {
      uint8 metadataType = uint8(metadata[0]);
      // Metadata Types
      // 0: use the stored handler and inject the metadata
      // 1: use the handler specified in the metadata
      metadata_ = metadata[1:];
      if (metadataType == 1) {
        (handler, metadata_) = abi.decode(metadata_, (IRewardHandler, bytes));
        _assertHandlerRegistered($, handler);
      }
    }

    IERC20(reward).safeTransferFrom(_msgSender(), address(this), amount);
    IERC20(reward).forceApprove(address(handler), amount);
    handler.handleReward(eolVault, reward, amount, metadata);
  }
}
