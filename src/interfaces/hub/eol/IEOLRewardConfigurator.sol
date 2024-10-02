// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IRewardConfigurator } from '../reward/IRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../reward/IRewardDistributor.sol';

/**
 * @title IEOLRewardConfigurator
 * @author Manythings Pte. Ltd.
 * @dev Interface for configuring EOL reward distribution settings.
 */
interface IEOLRewardConfigurator is IRewardConfigurator {
  /**
   * @notice Emitted when a reward distribution type is set for an EOL vault and asset pair.
   * @param eolVault The address of the EOL vault.
   * @param asset The address of the asset.
   * @param distributionType The type of distribution set.
   */
  event RewardDistributionTypeSet(
    address indexed eolVault, address indexed asset, DistributionType indexed distributionType
  );

  /**
   * @notice Emitted when a default distributor is set for a distribution type.
   * @param distributionType The type of distribution.
   * @param rewardDistributor The address of the default reward distributor.
   */
  event DefaultDistributorSet(DistributionType indexed distributionType, IRewardDistributor indexed rewardDistributor);

  /**
   * @notice Emitted when a reward distributor is registered.
   * @param distributor The address of the registered reward distributor.
   */
  event RewardDistributorRegistered(IRewardDistributor indexed distributor);

  /**
   * @notice Emitted when a reward distributor is unregistered.
   * @param distributor The address of the unregistered reward distributor.
   */
  event RewardDistributorUnregistered(IRewardDistributor indexed distributor);

  /**
   * @notice Error thrown when a default distributor is not set for a distribution type.
   * @param distributionType_ The distribution type without a default distributor.
   */
  error IEOLRewardConfigurator__DefaultDistributorNotSet(DistributionType distributionType_);

  /**
   * @notice Error thrown when attempting to unregister the default distributor.
   */
  error IEOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed();

  /**
   * @notice Error thrown when an invalid reward configurator is provided.
   */
  error IEOLRewardConfigurator__InvalidRewardConfigurator();

  /**
   * @notice Error thrown when attempting to register an already registered reward distributor.
   */
  error IEOLRewardConfigurator__RewardDistributorAlreadyRegistered();

  /**
   * @notice Error thrown when attempting to use an unregistered reward distributor.
   */
  error IEOLRewardConfigurator__RewardDistributorNotRegistered();

  /**
   * @notice Returns the distribution type for a given EOL vault and asset pair.
   * @param eolVault The address of the EOL vault.
   * @param asset The address of the asset.
   * @return The distribution type.
   */
  function distributionType(address eolVault, address asset) external view returns (DistributionType);

  /**
   * @notice Returns the default distributor for a given distribution type.
   * @param distributionType_ The type of distribution.
   * @return The address of the default reward distributor.
   */
  function defaultDistributor(DistributionType distributionType_) external view returns (IRewardDistributor);

  /**
   * @notice Checks if a reward distributor is registered.
   * @param distributor The address of the reward distributor to check.
   * @return A boolean indicating whether the distributor is registered.
   */
  function isDistributorRegistered(IRewardDistributor distributor) external view returns (bool);

  /**
   * @notice Sets the reward distribution type for an EOL vault and asset pair.
   * @param eolVault The address of the EOL vault.
   * @param asset The address of the asset.
   * @param distributionType_ The type of distribution to set.
   */
  function setRewardDistributionType(address eolVault, address asset, DistributionType distributionType_) external;

  /**
   * @notice Sets the default distributor for a distribution type.
   * @param distributor The address of the reward distributor to set as default.
   */
  function setDefaultDistributor(IRewardDistributor distributor) external;

  /**
   * @notice Registers a new reward distributor.
   * @param distributor The address of the reward distributor to register.
   */
  function registerDistributor(IRewardDistributor distributor) external;
}
