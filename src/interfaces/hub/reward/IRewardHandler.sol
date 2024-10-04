// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IRewardHandler
 * @notice Common interface for handling the distribution of rewards.
 */
interface IRewardHandler {
  enum HandlerType {
    Unspecified,
    Middleware,
    Endpoint
  }

  enum DistributionType {
    Unspecified,
    Merkle,
    TWAB
  }

  /**
   * @notice Returns the type of the reward handler
   * @return handlerType_ The type of the reward handler
   */
  function handlerType() external view returns (HandlerType handlerType_);

  /**
   * @notice Returns the distribution type of the reward handler
   * @return distributionType_ The distribution type of the reward handler
   */
  function distributionType() external view returns (DistributionType distributionType_);

  /**
   * @notice Returns the description of the reward handler
   * @return description_ The description of the reward handler
   */
  function description() external view returns (string memory description_);

  /**
   * @notice Checks if the specified dispatcher is allowed to call `handleReward`
   * @return isDispatchable_ True if the dispatcher is allowed to call `handleReward`
   */
  function isDispatchable(address dispatcher) external view returns (bool isDispatchable_);

  /**
   * @notice Handles the distribution of rewards for the specified vault and reward
   * @dev This method can only be called by the account that is allowed to dispatch rewards by `isDispatchable`
   */
  function handleReward(address eolVault, address reward, uint256 amount, bytes calldata metadata) external;
}
