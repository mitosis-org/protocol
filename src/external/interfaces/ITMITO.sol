// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/interfaces/IERC20.sol';

interface ITMITO is IERC20 {
  // =========================== EVENTS =========================== //

  /**
   * @notice Emitted when extra rewards are added to the contract.
   * @param amount The amount of MITO added as extra rewards
   */
  event ExtraRewardsAdded(uint256 amount);

  /**
   * @notice Emitted when the MITO:TMITO ratio is finalized.
   * @param totalMITOAmount The total MITO amount at finalization
   * @param totalTMITOAmount The total TMITO amount at finalization
   */
  event RatioFinalized(uint256 totalMITOAmount, uint256 totalTMITOAmount);

  /**
   * @notice Emitted when MITO is converted to TMITO after ratio is fixed.
   * @param account The address that converted the MITO to TMITO
   * @param to The address that received the TMITO
   * @param mitoAmount The amount of MITO converted
   * @param tmitoAmount The amount of TMITO minted
   */
  event ConvertedMITOToTMITO(
    address indexed account, address indexed to, uint256 mitoAmount, uint256 tmitoAmount
  );

  /**
   * @notice Emitted when tMITO tokens are minted.
   * @param to The address that received the tokens
   * @param amount The amount of tokens minted
   */
  event Minted(address indexed to, uint256 amount);

  /**
   * @notice Emitted when tMITO tokens are redeemed for MITO and extra rewards.
   * @param account The address that redeemed the tokens
   * @param to The address that received the MITO
   * @param tmitoAmount The amount of tMITO tokens burned
   * @param baseAmount The amount of base MITO received (1:1)
   * @param extraRewardAmount The amount of extra MITO received
   * @param totalAmount The total amount of MITO received (base + extra)
   */
  event Redeemed(
    address indexed account,
    address indexed to,
    uint256 tmitoAmount,
    uint256 baseAmount,
    uint256 extraRewardAmount,
    uint256 totalAmount
  );

  /**
   * @notice Emitted when the lockup end time is set.
   * @param lockupEndTime The new lockup end timestamp
   */
  event LockupEndTimeSet(uint48 lockupEndTime);

  // =========================== ERRORS =========================== //

  error TMITO__LockupNotEnded();
  error TMITO__ZeroAmount();
  error TMITO__ZeroAddress();
  error TMITO__RatioAlreadyFinalized();
  error TMITO__RatioNotFinalized();

  // =========================== VIEW FUNCTIONS =========================== //

  /**
   * @notice Returns the total amount of extra MITO rewards.
   * @return The total amount of extra MITO rewards
   */
  function totalExtraRewards() external view returns (uint256);

  /**
   * @notice Returns the lockup end timestamp.
   * @return The timestamp when lockup ends
   */
  function lockupEndTime() external view returns (uint48);

  /**
   * @notice Previews the total MITO amount a user would receive when redeeming tMITO.
   * @param tmitoAmount The amount of tMITO tokens to redeem
   * @return baseAmount The base MITO amount (1:1 ratio)
   * @return extraRewardAmount The extra MITO reward amount
   * @return totalAmount The total MITO amount (base + extra rewards)
   */
  function previewRedeem(uint256 tmitoAmount)
    external
    view
    returns (uint256 baseAmount, uint256 extraRewardAmount, uint256 totalAmount);

  /**
   * @notice Calculates the extra MITO rewards a user would receive for a given tMITO amount.
   * @param tmitoAmount The amount of tMITO tokens
   * @return The amount of extra MITO rewards
   */
  function previewExtraRewards(uint256 tmitoAmount) external view returns (uint256);

  /**
   * @notice Previews the amount of TMITO tokens that would be minted for a given MITO amount.
   * @param mitoAmount The amount of MITO to convert
   * @return tmitoAmount The amount of TMITO that would be minted
   */
  function previewConvert(uint256 mitoAmount) external view returns (uint256 tmitoAmount);

  /**
   * @notice Checks if the lockup period has ended.
   * @return Whether the lockup period has ended
   */
  function isLockupEnded() external view returns (bool);

  /**
   * @notice Returns whether the MITO:TMITO ratio has been finalized.
   * @return True if the ratio has been finalized, false otherwise
   */
  function ratioFinalized() external view returns (bool);

  // =========================== MUTATIVE FUNCTIONS =========================== //

  /**
   * @notice Mints tMITO tokens to a user.
   * @dev Only addresses with MINTER_ROLE can call this function.
   * @param to The address to mint tokens to
   */
  function mint(address to) external payable;

  /**
   * @notice Adds extra MITO rewards to the contract.
   * @dev Only addresses with REWARD_MANAGER_ROLE can call this function.
   */
  function addExtraRewards() external payable;

  /**
   * @notice Converts MITO to TMITO based on finalized ratio.
   * @dev Can only be called after ratio is finalized.
   * @param to The address to receive the TMITO
   */
  function convertMITOToTMITO(address to) external payable;

  /**
   * @notice Redeems tMITO tokens for MITO and extra rewards.
   * @dev Can only be called after lockup period ends.
   * @param to The address to receive the MITO
   * @param tmitoAmount The amount of tMITO tokens to redeem
   */
  function redeem(address to, uint256 tmitoAmount) external;

  // =========================== ADMIN FUNCTIONS =========================== //

  /**
   * @notice Sets the lockup end time.
   * @dev Only addresses with DEFAULT_ADMIN_ROLE can call this function.
   * @param lockupEndTime_ The new lockup end timestamp
   */
  function setLockupEndTime(uint48 lockupEndTime_) external;
}
