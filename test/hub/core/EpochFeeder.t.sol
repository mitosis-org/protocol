// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';

import { EpochFeeder } from '../../../src/hub/core/EpochFeeder.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EpochFeederTest is Toolkit {
  using SafeCast for uint256;

  address owner = makeAddr('owner');

  EpochFeeder feeder;

  function setUp() public {
    feeder = EpochFeeder(
      address(
        new ERC1967Proxy(
          address(new EpochFeeder()), abi.encodeCall(EpochFeeder.initialize, (owner, block.timestamp + 1 days, 1 days))
        )
      )
    );
  }

  function test_init() public view {
    assertEq(feeder.owner(), owner);
    assertEq(feeder.clock(), block.timestamp.toUint48());
    assertEq(feeder.epoch(), 0);
    assertEq(feeder.interval(), 1 days);
  }

  function test_epochAt() public {
    uint48 now_ = block.timestamp.toUint48();
    vm.warp(block.timestamp + 5 days);
    feeder.update();

    for (uint256 i = 0; i < 10; i++) {
      assertEq(feeder.epochAt((now_ + i * 1 days).toUint48()), i);
    }
  }

  function test_epochToTime() public {
    uint48 now_ = block.timestamp.toUint48();
    vm.warp(block.timestamp + 5 days);
    feeder.update();

    for (uint256 i = 0; i < 10; i++) {
      assertEq(feeder.epochToTime(i.toUint96()), now_ + i * 1 days);
    }
  }

  function test_update() public {
    uint48 now_ = block.timestamp.toUint48();
    vm.warp(block.timestamp + 5 days);

    for (uint256 i = 0; i < 5; i++) {
      vm.expectEmit();
      emit IEpochFeeder.EpochRolled(i.toUint96(), (now_ + i * 1 days).toUint48());
    }

    feeder.update();
  }

  function test_setInterval() public {
    uint48 now_ = block.timestamp.toUint48();
    vm.warp(block.timestamp + 5 days);

    for (uint256 i = 0; i < 5; i++) {
      vm.expectEmit();
      emit IEpochFeeder.EpochRolled(i.toUint96(), (now_ + i * 1 days).toUint48());
    }

    vm.expectEmit();
    emit IEpochFeeder.IntervalUpdated(2 days);

    vm.prank(owner);
    feeder.setInterval(2 days);

    vm.warp(block.timestamp + 6 days);
    feeder.update();
  }
}
