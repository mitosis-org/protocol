// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IRewardHandler } from '../../interfaces/hub/reward/IRewardHandler.sol';
import { IRoutingRewardHandlerStorageV1 } from '../../interfaces/hub/reward/IRoutingRewardHandler.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/**
 * @title RoutingRewardHandlerStorageV1
 * @notice A storage, getter definition for the RoutingRewardHandler (version 1)
 */
contract RoutingRewardHandlerStorageV1 is IRoutingRewardHandlerStorageV1 {
  using ERC7201Utils for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct HandlerConfig {
    IRewardHandler.DistributionType distributionType;
    IRewardHandler handler;
  }

  struct StorageV1 {
    EnumerableSet.AddressSet allowedHandlers;
    mapping(address eolVault => mapping(address reward => HandlerConfig handlerConfig)) handlerConfigs;
    // note: We strictly manage the DefaultDistributor. DistributionTypes without a set
    // DefaultDistributor cannot be configured as the distribution method for assets.
    // And once initialized, the DefaultDistributor cannot be set to a zero address.
    mapping(IRewardHandler.DistributionType distributionType => IRewardHandler handler) defaultHandlers;
  }

  string private constant _NAMESPACE = 'mitosis.storage.RoutingRewardHandlerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  /**
   * @inheritdoc IRoutingRewardHandlerStorageV1
   */
  function distributionType(address eolVault, address reward)
    external
    view
    returns (IRewardHandler.DistributionType distributionType_)
  {
    return _distributionType(_getStorageV1(), eolVault, reward);
  }

  /**
   * @inheritdoc IRoutingRewardHandlerStorageV1
   */
  function route(address eolVault, address reward) external view returns (IRewardHandler handler_) {
    return _route(_getStorageV1(), eolVault, reward);
  }

  /**
   * @inheritdoc IRoutingRewardHandlerStorageV1
   */
  function defaultHandler(IRewardHandler.DistributionType distributionType_)
    external
    view
    returns (IRewardHandler defaultHandler_)
  {
    return _getStorageV1().defaultHandlers[distributionType_];
  }

  /**
   * @inheritdoc IRoutingRewardHandlerStorageV1
   */
  function allowedHandlers(uint256 offset, uint256 size) external view returns (IRewardHandler[] memory handlers_) {
    StorageV1 storage $ = _getStorageV1();

    uint256 handlersLength = $.allowedHandlers.length();
    if (offset + size > handlersLength) size = handlersLength - offset;

    handlers_ = new IRewardHandler[](size);
    for (uint256 i = 0; i < size; i++) {
      handlers_[i] = IRewardHandler($.allowedHandlers.at(offset + i));
    }

    return handlers_;
  }

  /**
   * @inheritdoc IRoutingRewardHandlerStorageV1
   */
  function isHandlerAllowed(IRewardHandler handler_) external view returns (bool isRegistered_) {
    return _isHandlerAllowed(_getStorageV1(), handler_);
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function _setHandlerConfig(StorageV1 storage $, address eolVault, address reward, IRewardHandler handler_) internal {
    require(address(handler_).code.length > 0, StdError.InvalidAddress('handler'));

    _assertHandlerRegistered($, handler_);

    $.handlerConfigs[eolVault][reward] =
      HandlerConfig({ distributionType: IRewardHandler.DistributionType.Unspecified, handler: handler_ });

    emit HandlerConfigSet(eolVault, reward, handler_, IRewardHandler.DistributionType.Unspecified);
  }

  function _setHandlerConfig(
    StorageV1 storage $,
    address eolVault,
    address reward,
    IRewardHandler.DistributionType distributionType_
  ) internal {
    _assertDefaultHandlerSet($, distributionType_);

    $.handlerConfigs[eolVault][reward] =
      HandlerConfig({ distributionType: distributionType_, handler: IRewardHandler(address(0)) });

    emit HandlerConfigSet(eolVault, reward, IRewardHandler(address(0)), distributionType_);
  }

  function _setDefaultHandler(
    StorageV1 storage $,
    IRewardHandler.DistributionType distributionType_,
    IRewardHandler defaultHandler_
  ) internal {
    require(address(defaultHandler_).code.length > 0, StdError.InvalidAddress('defaultHandler'));

    _assertHandlerRegistered($, defaultHandler_);

    $.defaultHandlers[distributionType_] = defaultHandler_;

    emit DefaultHandlerSet(distributionType_, defaultHandler_);
  }

  function _registerHandler(StorageV1 storage $, IRewardHandler handler_) internal {
    require(address(handler_).code.length > 0, StdError.InvalidAddress('handler'));

    _assertHandlerNotRegistered($, handler_);

    IRewardHandler.DistributionType distributionType_ = handler_.distributionType();
    $.allowedHandlers.add(address(handler_));

    emit HandlerRegistered(distributionType_, handler_);
  }

  function _unregisterHandler(StorageV1 storage $, IRewardHandler handler_) internal {
    _assertHandlerRegistered($, handler_);

    IRewardHandler.DistributionType distributionType_ = handler_.distributionType();
    $.allowedHandlers.remove(address(handler_));

    emit HandlerUnregistered(distributionType_, handler_);
  }

  // ============================ NOTE: INTERNRAL FUNCTIONS ============================ //

  function _distributionType(StorageV1 storage $, address eolVault, address reward)
    internal
    view
    returns (IRewardHandler.DistributionType distributionType_)
  {
    HandlerConfig memory config = $.handlerConfigs[eolVault][reward];
    return address(config.handler) != address(0) ? config.handler.distributionType() : config.distributionType;
  }

  function _route(StorageV1 storage $, address eolVault, address reward)
    internal
    view
    returns (IRewardHandler handler_)
  {
    HandlerConfig memory config = $.handlerConfigs[eolVault][reward];
    return address(config.handler) != address(0) ? config.handler : $.defaultHandlers[config.distributionType];
  }

  function _isHandlerAllowed(StorageV1 storage $, IRewardHandler handler_) internal view returns (bool isRegistered_) {
    return $.allowedHandlers.contains(address(handler_));
  }

  // ============================ NOTE: ASSERTIONS ============================ //

  function _assertDefaultHandlerSet(StorageV1 storage $, IRewardHandler.DistributionType distributionType_)
    internal
    view
  {
    require(
      address($.defaultHandlers[distributionType_]) != address(0),
      IRoutingRewardHandlerStorageV1__DefaultHandlerNotSet(distributionType_)
    );
  }

  function _assertHandlerNotRegistered(StorageV1 storage $, IRewardHandler handler_) internal view {
    require(!_isHandlerAllowed($, handler_), IRoutingRewardHandlerStorageV1__HandlerAlreadyRegistered());
  }

  function _assertHandlerRegistered(StorageV1 storage $, IRewardHandler handler_) internal view {
    require(_isHandlerAllowed($, handler_), IRoutingRewardHandlerStorageV1__HandlerNotRegistered());
  }
}
