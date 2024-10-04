// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IRewardHandler } from '../../interfaces/hub/reward/IRewardHandler.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/**
 * @title BaseHandler
 * @notice This contract is intended to be inherited by other reward handler contracts
 * @dev Base contract for reward handlers
 */
abstract contract BaseHandler is IRewardHandler, ContextUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.BaseHandler
  struct BaseHandlerStorage {
    string description;
  }

  HandlerType private immutable _handlerType;
  DistributionType private immutable _distributionType;

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.BaseHandler';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getBaseHandlerStorage() private view returns (BaseHandlerStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // =========================== NOTE: INITIALIZERS  =========================== //

  constructor(HandlerType handlerType_, DistributionType distributionType_, string memory description_) {
    _handlerType = handlerType_;
    _distributionType = distributionType_;
    _getBaseHandlerStorage().description = description_;
  }

  function __BaseHandler_init() internal onlyInitializing {
    __Context_init();
  }

  // =========================== NOTE: VIEW FUNCTIONS  =========================== //

  /**
   * @inheritdoc IRewardHandler
   */
  function handlerType() public view override returns (HandlerType) {
    return _handlerType;
  }

  /**
   * @inheritdoc IRewardHandler
   */
  function distributionType() public view override returns (DistributionType) {
    return _distributionType;
  }

  /**
   * @inheritdoc IRewardHandler
   */
  function description() external view override returns (string memory) {
    return _getBaseHandlerStorage().description;
  }

  /**
   * @inheritdoc IRewardHandler
   */
  function isDispatchable(address dispatcher) external view override returns (bool) {
    return _isDispatchable(dispatcher);
  }

  // =========================== NOTE: MUTATIVE FUNCTIONS  =========================== //

  /**
   * @inheritdoc IRewardHandler
   */
  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external override {
    require(_isDispatchable(_msgSender()), StdError.Unauthorized());
    _handleReward(eolVault, reward, amount, metadata);
  }

  // =========================== NOTE: VIRTUAL FUNCTIONS  =========================== //

  /**
   * @notice Checker for dispatchability
   * @dev override this method to implement custom dispatchability logic
   */
  function _isDispatchable(address dispatcher) internal view virtual returns (bool);

  /**
   * @notice Handler for reward distribution
   * @dev override this method to implement custom reward distribution logic
   */
  function _handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) internal virtual;
}
