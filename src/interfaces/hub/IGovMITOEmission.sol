// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IGovMITO } from './IGovMITO.sol';

interface IGovMITOEmission {
  error NotEnoughBalance();
  error NotEnoughReserve();

  event Deposited(uint256 amount);
  event Withdrawn(uint256 amount);
  event ValidatorRewardRequested(uint96 indexed epoch, uint256 amount);
  event ValidatorRewardReserved(uint96 indexed epoch, uint256 amount);
  event ValidatorRewardRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

  /**
   * @notice Returns the GovMITO token contract
   */
  function govMITO() external view returns (IGovMITO);

  /**
   * @notice Returns the total reserved amount of gMITO tokens
   */
  function totalReserved() external view returns (uint256);

  /**
   * @notice Returns the validator reward for a given epoch
   * @param epoch Epoch number
   * @return amount The total amount of gMITO tokens reserved for the validator reward
   * @return claimed The amount of gMITO tokens already claimed
   */
  function validatorReward(uint96 epoch) external view returns (uint256 amount, uint256 claimed);

  /**
   * @notice Returns the validator reward recipient
   */
  function validatorRewardRecipient() external view returns (address);

  /**
   * @notice Deposits ETH and mints gMITO tokens to this contract
   */
  function deposit() external payable;

  /**
   * @notice Forces withdrawal of gMITO tokens to owner
   * @param amount Amount of gMITO tokens to withdraw
   */
  function withdraw(uint256 amount) external;

  /**
   * @notice Requests a validator reward
   * @param epoch Epoch number
   * @param recipient Address of the recipient
   * @param amount Amount of gMITO tokens to request
   */
  function requestValidatorReward(uint96 epoch, address recipient, uint256 amount) external;

  /**
   * @notice Reserves a validator reward
   * @param epoch Epoch number
   * @param amount Amount of gMITO tokens to reserve
   */
  function reserveValidatorReward(uint96 epoch, uint256 amount) external;

  /**
   * @notice Sets the validator reward recipient
   * @param recipient New validator reward recipient
   */
  function setValidatorRewardRecipient(address recipient) external;
}
