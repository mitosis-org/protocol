// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { ValidatorContributionFeed } from '../../../src/hub/core/ValidatorContributionFeed.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  IValidatorContributionFeedNotifier,
  ValidatorWeight
} from '../../../src/interfaces/hub/core/IValidatorContributionFeed.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockEpochFeeder {
  uint96 epoch_ = 1;

  function epoch() external view returns (uint96) {
    return epoch_;
  }

  function setEpoch(uint96 newEpoch) external {
    epoch_ = newEpoch;
  }
}

contract MockNotifier {
  uint256 public callCount;

  function notifyReportFinalized(uint96) external {
    callCount++;
  }
}

contract ValidatorContributionFeedTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  address feeder = makeAddr('feeder');

  MockEpochFeeder epochFeeder;
  MockNotifier notifier;
  ValidatorContributionFeed feed;

  function setUp() public {
    epochFeeder = new MockEpochFeeder();
    notifier = new MockNotifier();

    feed = ValidatorContributionFeed(
      address(
        new ERC1967Proxy(
          address(new ValidatorContributionFeed()),
          abi.encodeCall(ValidatorContributionFeed.initialize, (owner, address(epochFeeder)))
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
    epochFeeder.setEpoch(2);

    vm.prank(owner);
    feed.setNotifier(IValidatorContributionFeedNotifier(address(notifier)));

    vm.startPrank(feeder);
    feed.initializeReport(
      IValidatorContributionFeed.InitReportRequest({ totalReward: 300, totalWeight: 300, numOfValidators: 300 })
    );

    for (uint256 i = 0; i < 6; i++) {
      ValidatorWeight[] memory weights = new ValidatorWeight[](50);
      for (uint256 j = 0; j < 50; j++) {
        weights[j] = ValidatorWeight({ addr: makeAddr(string.concat('val-', ((i * 50) + j).toString())), weight: 1 });
      }
      feed.pushValidatorWeights(weights);
    }

    feed.finalizeReport();
    vm.stopPrank();

    assertEq(notifier.callCount(), 1);
  }
}
