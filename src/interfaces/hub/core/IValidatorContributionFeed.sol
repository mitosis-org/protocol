// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IEpochFeeder } from './IEpochFeeder.sol';

struct ValidatorWeight {
  address addr;
  uint96 weight; // max 79 billion * 1e18
}

enum ReportStatus {
  NONE,
  INITIALIZED,
  FINALIZED
}

interface IValidatorContributionFeedNotifier {
  function notifyReportFinalized(uint96 epoch) external;
}

interface IValidatorContributionFeed {
  struct ReportRequest {
    uint128 totalReward;
    uint128 totalWeight;
    ValidatorWeight[] weights;
  }

  struct InitReportRequest {
    uint128 totalReward;
    uint128 totalWeight;
    uint16 numOfValidators;
  }

  struct Summary {
    uint128 totalReward;
    uint128 totalWeight;
    uint16 numOfValidators;
  }

  event ReportInitialized(uint96 epoch, uint128 totalReward, uint128 totalWeight, uint16 numOfValidators);
  event WeightsPushed(uint96 epoch, uint128 totalWeight, uint16 numOfValidators);
  event ReportFinalized(uint96 epoch);

  error InvalidReportStatus();
  error InvalidWeightAddress();
  error InvalidTotalWeight();
  error InvalidValidatorCount();
  error EpochNotFinalized();
  error NotifierNotSet();

  function epochFeeder() external view returns (IEpochFeeder);

  function weightCount(uint96 epoch) external view returns (uint256);

  function weightAt(uint96 epoch, uint256 index) external view returns (ValidatorWeight memory);

  function weightOf(uint96 epoch, address valAddr) external view returns (ValidatorWeight memory, bool);

  function available(uint96 epoch) external view returns (bool);

  function summary(uint96 epoch) external view returns (Summary memory);

  function initializeReport(InitReportRequest calldata request) external;

  function pushValidatorWeights(ValidatorWeight[] calldata weights) external;

  function finalizeReport() external;
}
