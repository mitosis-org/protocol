// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { ValidatorContributionFeed } from '../../../src/hub/validator/ValidatorContributionFeed.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/validator/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  ValidatorWeight
} from '../../../src/interfaces/hub/validator/IValidatorContributionFeed.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';
import { MockContract } from '../../util/MockContract.sol';

contract ValidatorContributionFeedTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  address feeder = makeAddr('feeder');

  MockContract epochFeeder;
  ValidatorContributionFeed feed;

  function setUp() public {
    epochFeeder = new MockContract();
    epochFeeder.setStatic(IEpochFeeder.epoch.selector);

    feed = ValidatorContributionFeed(
      address(
        new ERC1967Proxy(
          address(new ValidatorContributionFeed(IEpochFeeder(address(epochFeeder)))),
          abi.encodeCall(ValidatorContributionFeed.initialize, (owner))
        )
      )
    );

    vm.startPrank(owner);
    feed.grantRole(feed.FEEDER_ROLE(), feeder);
    vm.stopPrank();
  }

  function test_init() public view {
    assertEq(feed.owner(), owner);
    assertEq(address(feed.epochFeeder()), address(epochFeeder));
  }

  function test_report() public {
    epochFeeder.setRet(IEpochFeeder.epoch.selector, abi.encode(uint256(2)), false, abi.encode(uint256(2)));

    vm.startPrank(feeder);
    feed.initializeReport(IValidatorContributionFeed.InitReportRequest({ totalWeight: 300, numOfValidators: 300 }));

    for (uint256 i = 0; i < 6; i++) {
      ValidatorWeight[] memory weights = new ValidatorWeight[](50);
      for (uint256 j = 0; j < 50; j++) {
        weights[j] = ValidatorWeight({
          addr: makeAddr(string.concat('val-', ((i * 50) + j).toString())),
          weight: 1,
          collateralRewardShare: 1e18,
          delegationRewardShare: 1e18
        });
      }
      feed.pushValidatorWeights(weights);
    }

    feed.finalizeReport();
    vm.stopPrank();
  }
}
