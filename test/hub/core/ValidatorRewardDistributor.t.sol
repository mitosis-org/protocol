// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/core/EpochFeeder.sol';
import { ValidatorRewardDistributor } from '../../../src/hub/core/ValidatorRewardDistributor.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import {
  IValidatorContributionFeed, ValidatorWeight
} from '../../../src/interfaces/hub/core/IValidatorContributionFeed.sol';
import { IValidatorDelegationManager } from '../../../src/interfaces/hub/core/IValidatorDelegationManager.sol';
import { IValidatorRegistry } from '../../../src/interfaces/hub/core/IValidatorRegistry.sol';
import { IValidatorRewardDistributor } from '../../../src/interfaces/hub/core/IValidatorRewardDistributor.sol';
import { IGovMITO } from '../../../src/interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../../src/interfaces/hub/IGovMITOEmission.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorRewardDistributorTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  uint256 epochInterval = 100 seconds;

  MockContract govMITO;
  MockContract govMITOEmission;
  MockContract registry;
  MockContract delegationManager;
  EpochFeeder epochFeed;
  MockContract contributionFeed;
  ValidatorRewardDistributor distributor;

  function setUp() public {
    govMITO = new MockContract();
    govMITO.setStatic(IERC20.totalSupply.selector, true);
    govMITO.setStatic(IERC20.balanceOf.selector, true);

    govMITOEmission = new MockContract();

    registry = new MockContract();
    registry.setStatic(IValidatorRegistry.validatorInfo.selector, true);
    registry.setStatic(IValidatorRegistry.validatorInfoAt.selector, true);
    registry.setStatic(IValidatorRegistry.MAX_COMMISSION_RATE.selector, true);

    delegationManager = new MockContract();
    delegationManager.setStatic(IValidatorDelegationManager.totalDelegationTWABAt.selector, true);
    delegationManager.setStatic(IValidatorDelegationManager.stakedTWABAt.selector, true);

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
          (
            owner,
            address(epochFeed),
            address(registry),
            address(delegationManager),
            address(contributionFeed),
            address(govMITOEmission)
          )
        )
      )
    );
  }

  function test_init() public view {
    assertEq(distributor.owner(), owner);
    assertEq(address(distributor.epochFeeder()), address(epochFeed));
    assertEq(address(distributor.validatorRegistry()), address(registry));
    assertEq(address(distributor.validatorDelegationManager()), address(delegationManager));
    assertEq(address(distributor.validatorContributionFeed()), address(contributionFeed));
    assertEq(address(distributor.govMITO()), address(govMITO));
    assertEq(address(distributor.govMITOEmission()), address(govMITOEmission));
  }

  // TODO(eddy): cover all the functions
}
