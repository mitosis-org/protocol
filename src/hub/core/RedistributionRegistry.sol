// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { IRedistributionRegistry } from '../../interfaces/hub/core/IRedistributionRegistry.sol';
import { StdError } from '../../lib/StdError.sol';
import { RedistributionRegistryStorageV1 } from './RedistributionRegistryStorageV1.sol';

contract RedistributionRegistry is IRedistributionRegistry, RedistributionRegistryStorageV1, ContextUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address mitosis_) external initializer {
    StorageV1 storage $ = _getStorageV1();

    $.mitosis = mitosis_;
  }

  /**
   * @inheritdoc IRedistributionRegistry
   */
  function mitosis() external view returns (address) {
    return _getStorageV1().mitosis;
  }

  /**
   * @inheritdoc IRedistributionRegistry
   */
  function isRedistributionEnabled(address account) external view returns (bool) {
    return _getStorageV1().redistributionEnabled[account];
  }

  /**
   * @inheritdoc IRedistributionRegistry
   */
  function enableRedistribution() external {
    return _enableRedistribution(_getStorageV1(), _msgSender());
  }

  /**
   * @inheritdoc IRedistributionRegistry
   */
  function enableRedistributionByMitosis(address account) external {
    StorageV1 storage $ = _getStorageV1();
    require(_msgSender() == $.mitosis, StdError.Unauthorized());
    return _enableRedistribution($, account);
  }

  function _enableRedistribution(StorageV1 storage $, address account) internal {
    $.redistributionEnabled[account] = true;
    emit RedistributionEnabled(account);
  }
}
