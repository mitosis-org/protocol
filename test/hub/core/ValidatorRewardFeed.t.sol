// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { ValidatorRewardFeed } from '../../../src/hub/core/ValidatorRewardFeed.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorRewardFeed, Weight } from '../../../src/interfaces/hub/core/IValidatorRewardFeed.sol';
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

contract ValidatorRewardFeedTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address owner = makeAddr('owner');
  address feeder = makeAddr('feeder');

  ContractStub epochFeederStub;
  ValidatorRewardFeed feed;

  function setUp() public {
    epochFeederStub = new ContractStub();
    feed = ValidatorRewardFeed(
      address(
        new ERC1967Proxy(
          address(new ValidatorRewardFeed()),
          abi.encodeCall(ValidatorRewardFeed.initialize, (owner, address(epochFeederStub)))
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
      IValidatorRewardFeed.InitReportRequest({ totalReward: 300, totalWeight: 300, numOfValidators: 300 })
    );

    for (uint256 i = 0; i < 6; i++) {
      Weight[] memory weights = new Weight[](50);
      for (uint256 j = 0; j < 50; j++) {
        weights[j] = Weight({ addr: makeAddr(string.concat('val-', ((i * 50) + j).toString())), weight: 1 });
      }
      feed.pushWeights(weights);
    }

    feed.finalizeReport();
    vm.stopPrank();
  }

  function _stub_epoch(uint96 ret) internal {
    epochFeederStub.setReturn(IEpochFeeder.epoch.selector, ContractStub.Ret({ err: false, data: abi.encode(ret) }));
  }
}
