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
  IValidatorContributionFeed, ValidatorWeight
} from '../../../src/interfaces/hub/core/IValidatorContributionFeed.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ContractStub {
  struct Ret {
    bool err;
    bytes data;
  }

  mapping(bytes4 selector => Ret) private rets;

  function setReturn(bytes4 selector, Ret calldata ret) external {
    rets[selector] = ret;
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  fallback() external payable {
    bytes4 selector = msg.sig;
    Ret memory ret = rets[selector];
    bytes memory data = ret.data;
    if (ret.err) {
      assembly {
        revert(add(data, 32), mload(data))
      }
    } else {
      assembly {
        return(add(data, 32), mload(data))
      }
    }
  }
}

contract ValidatorContributionFeedTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  address feeder = makeAddr('feeder');

  ContractStub epochFeederStub;
  ValidatorContributionFeed feed;

  function setUp() public {
    epochFeederStub = new ContractStub();
    feed = ValidatorContributionFeed(
      address(
        new ERC1967Proxy(
          address(new ValidatorContributionFeed()),
          abi.encodeCall(ValidatorContributionFeed.initialize, (owner, address(epochFeederStub)))
        )
      )
    );

    vm.startPrank(owner);
    feed.grantRole(feed.FEEDER_ROLE(), feeder);
    vm.stopPrank();
  }

  function test_init() public view {
    assertEq(feed.owner(), owner);
    assertEq(address(feed.epochFeeder()), address(epochFeederStub));
  }

  function test_report() public {
    _stub_epoch(2);

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
  }

  function _stub_epoch(uint96 ret) internal {
    epochFeederStub.setReturn(IEpochFeeder.epoch.selector, ContractStub.Ret({ err: false, data: abi.encode(ret) }));
  }
}
