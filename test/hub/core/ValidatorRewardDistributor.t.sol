// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { Toolkit } from '../../util/Toolkit.sol';
import { ValidatorRewardDistributor } from '../../../src/hub/core/ValidatorRewardDistributor.sol';
import { IGovMITO } from '../../../src/interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../../src/interfaces/hub/IGovMITOEmission.sol';
import { IValidatorManager } from '../../../src/interfaces/hub/core/IValidatorManager.sol';
import {
  IValidatorContributionFeed, ValidatorWeight
} from '../../../src/interfaces/hub/core/IValidatorContributionFeed.sol';
import { IValidatorRewardDistributor } from '../../../src/interfaces/hub/core/IValidatorRewardDistributor.sol';
import { EpochFeeder } from '../../../src/hub/core/EpochFeeder.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import { MockContract } from '../../util/MockContract.sol';
import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

contract ValidatorRewardDistributorTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  uint256 epochInterval = 100 seconds;

  MockContract govMITO;
  MockContract govMITOEmission;
  MockContract manager;
  EpochFeeder epochFeed;
  MockContract contributionFeed;
  ValidatorRewardDistributor distributor;

  function setUp() public {
    govMITO = new MockContract();
    govMITO.setStatic(IERC20.totalSupply.selector, true);
    govMITO.setStatic(IERC20.balanceOf.selector, true);

    govMITOEmission = new MockContract();

    manager = new MockContract();
    manager.setStatic(IValidatorManager.validatorInfo.selector, true);
    manager.setStatic(IValidatorManager.validatorInfoAt.selector, true);
    manager.setStatic(IValidatorManager.stakedTWABAt.selector, true);
    manager.setStatic(IValidatorManager.totalDelegationTWABAt.selector, true);
    manager.setStatic(IValidatorManager.MAX_COMMISSION_RATE.selector, true);

    contributionFeed = new MockContract();
    contributionFeed.setStatic(IValidatorContributionFeed.available.selector, true);
    contributionFeed.setStatic(IValidatorContributionFeed.weightOf.selector, true);
    contributionFeed.setStatic(IValidatorContributionFeed.summary.selector, true);

    epochFeed = EpochFeeder(
      _proxy(
        address(new EpochFeeder()),
        abi.encodeCall(EpochFeeder.initialize, (owner, block.timestamp + epochInterval, epochInterval))
      )
    );
    distributor = ValidatorRewardDistributor(
      _proxy(
        address(new ValidatorRewardDistributor(address(govMITO))),
        abi.encodeCall(
          ValidatorRewardDistributor.initialize,
          (owner, address(epochFeed), address(manager), address(contributionFeed), address(govMITOEmission))
        )
      )
    );
  }

  function test_init() public view {
    assertEq(distributor.owner(), owner);
    assertEq(address(distributor.epochFeeder()), address(epochFeed));
    assertEq(address(distributor.validatorManager()), address(manager));
    assertEq(address(distributor.validatorContributionFeed()), address(contributionFeed));
    assertEq(address(distributor.govMITO()), address(govMITO));
    assertEq(address(distributor.govMITOEmission()), address(govMITOEmission));
  }

  // TODO(eddy): cover all the functions
}
