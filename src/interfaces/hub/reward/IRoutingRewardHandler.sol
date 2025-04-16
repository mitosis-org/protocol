// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IAccessControlEnumerable } from '@oz-v5/access/extensions/IAccessControlEnumerable.sol';

import { IRewardHandler } from './IRewardHandler.sol';

/**
 * @title IRoutingRewardHandlerStorageV1
 * @notice Interface definition for the RoutingRewardHandlerStorageV1
 */
interface IRoutingRewardHandlerStorageV1 {
  event HandlerConfigSet(
    address indexed eolVault,
    address indexed reward,
    IRewardHandler handler,
    IRewardHandler.DistributionType distributionType
  );
  event DefaultHandlerSet(
    IRewardHandler.DistributionType indexed distributionType, IRewardHandler indexed defaultHandler
  );
  event HandlerRegistered(IRewardHandler.DistributionType indexed distributionType, IRewardHandler indexed handler);
  event HandlerUnregistered(IRewardHandler.DistributionType indexed distributionType, IRewardHandler indexed handler);

  error IRoutingRewardHandlerStorageV1__HandlerAlreadyRegistered();
  error IRoutingRewardHandlerStorageV1__HandlerNotRegistered();
  error IRoutingRewardHandlerStorageV1__DefaultHandlerNotSet(IRewardHandler.DistributionType distributionType);

  /**
   * @notice Returns the distribution type of the reward handler for the given EOLVault and reward
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   */
  function distributionType(address eolVault, address reward) external view returns (IRewardHandler.DistributionType);

  /**
   * @notice Returns the reward handler for the given EOLVault and reward
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   */
  function route(address eolVault, address reward) external view returns (IRewardHandler);

  /**
   * @notice Returns the default reward handler for the given distribution type
   * @param distributionType_ The distribution type
   */
  function defaultHandler(IRewardHandler.DistributionType distributionType_) external view returns (IRewardHandler);

  /**
   * @notice Iterates over the registered reward handlers for the given distribution type
   * @dev It will returns the entire list of handlers if the offset + size is greater than the number of handlers
   * @param offset The offset to start from
   * @param size The number of handlers to return
   */
  function allowedHandlers(uint256 offset, uint256 size) external view returns (IRewardHandler[] memory);

  /**
   * @notice Checks if the reward handler is allowed
   * @param handler_ The reward handler
   */
  function isHandlerAllowed(IRewardHandler handler_) external view returns (bool);
}

/**
 * @title IRoutingRewardHandler
 * @notice Interface definition for the RoutingRewardHandler
 */
interface IRoutingRewardHandler is IAccessControlEnumerable, IRoutingRewardHandlerStorageV1 {
  /**
   * @notice Sets the handler for the given EOLVault and reward, so that the reward can be dispatched via the specified handler
   * @dev Emits HandlerConfigSet event
   * @dev The handler must be registered before setting it
   * @dev The distribution type must not be set before setting the handler
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param handler The reward handler address
   */
  function setHandlerConfig(address eolVault, address reward, IRewardHandler handler) external;

  /**
   * @notice Sets the distribution type for the given EOLVault and reward, so that the reward can be dispatched via default handler
   * @dev Emits HandlerConfigSet event
   * @dev The default handler must be set before setting the distribution type
   * @dev The handler must not be set before setting the distribution type
   * @param eolVault The EOLVault address
   * @param reward The reward token address
   * @param distributionType_ The distribution type
   */
  function setHandlerConfig(address eolVault, address reward, IRewardHandler.DistributionType distributionType_)
    external;

  /**
   * @notice Sets the default reward handler for the given distribution type
   * @dev Emits DefaultHandlerSet event
   * @dev The default handler must be registered before setting it
   * @param distributionType_ The distribution type
   * @param defaultHandler_ The default reward handler
   */
  function setDefaultHandler(IRewardHandler.DistributionType distributionType_, IRewardHandler defaultHandler_)
    external;

  /**
   * @notice Registers the reward handler for the given distribution type
   * @dev Emits HandlerRegistered event
   * @dev The handler must not be registered before registering it
   * @param handler_ The reward handler
   */
  function registerHandler(IRewardHandler handler_) external;

  /**
   * @notice Unregisters the reward handler for the given distribution type
   * @dev Emits HandlerUnregistered event
   * @dev The handler must be registered before unregistering it
   * @param handler_ The reward handler to unregister
   */
  function unregisterHandler(IRewardHandler handler_) external;
}
