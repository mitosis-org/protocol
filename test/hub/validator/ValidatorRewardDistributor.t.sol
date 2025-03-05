// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/validator/EpochFeeder.sol';
import { ValidatorRewardDistributor } from '../../../src/hub/validator/ValidatorRewardDistributor.sol';
import { IGovMITO } from '../../../src/interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../../src/interfaces/hub/IGovMITOEmission.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/validator/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  ValidatorWeight
} from '../../../src/interfaces/hub/validator/IValidatorContributionFeed.sol';
import { IValidatorManager } from '../../../src/interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../../src/interfaces/hub/validator/IValidatorRewardDistributor.sol';
import { IValidatorStaking } from '../../../src/interfaces/hub/validator/IValidatorStaking.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorRewardDistributorTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  uint256 epochInterval = 100 seconds;

  MockContract govMITO;
  MockContract govMITOEmission;
  MockContract validatorManager;
  MockContract staking;
  EpochFeeder epochFeed;
  MockContract contributionFeed;
  ValidatorRewardDistributor distributor;

  function setUp() public {
    govMITO = new MockContract();
    govMITO.setStatic(IERC20.totalSupply.selector, true);
    govMITO.setStatic(IERC20.balanceOf.selector, true);

    govMITOEmission = new MockContract();

    validatorManager = new MockContract();
    validatorManager.setStatic(IValidatorManager.validatorInfo.selector, true);
    validatorManager.setStatic(IValidatorManager.validatorInfoAt.selector, true);
    validatorManager.setStatic(IValidatorManager.MAX_COMMISSION_RATE.selector, true);

    staking = new MockContract();
    staking.setStatic(IValidatorStaking.totalDelegationTWABAt.selector, true);
    staking.setStatic(IValidatorStaking.stakedTWABAt.selector, true);

    contributionFeed = new MockContract();
    contributionFeed.setStatic(IValidatorContributionFeed.available.selector, true);
    contributionFeed.setStatic(IValidatorContributionFeed.weightOf.selector, true);
    contributionFeed.setStatic(IValidatorContributionFeed.summary.selector, true);

    epochFeed = EpochFeeder(
      _proxy(
        address(new EpochFeeder()),
        abi.encodeCall(
          EpochFeeder.initialize, (owner, Time.timestamp() + epochInterval.toUint48(), epochInterval.toUint48())
        )
      )
    );
    distributor = ValidatorRewardDistributor(
      _proxy(
        address(
          new ValidatorRewardDistributor(
            address(epochFeed),
            address(validatorManager),
            address(staking),
            address(contributionFeed),
            address(govMITOEmission)
          )
        ),
        abi.encodeCall(ValidatorRewardDistributor.initialize, (owner))
      )
    );
  }

  function test_init() public view {
    assertEq(distributor.owner(), owner);
    assertEq(address(distributor.epochFeeder()), address(epochFeed));
    assertEq(address(distributor.validatorManager()), address(validatorManager));
    assertEq(address(distributor.validatorStaking()), address(staking));
    assertEq(address(distributor.validatorContributionFeed()), address(contributionFeed));
    assertEq(address(distributor.govMITOEmission()), address(govMITOEmission));
  }

  // TODO(eddy): cover all the functions
}
