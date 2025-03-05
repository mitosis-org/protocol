// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { LibClone } from '@solady/utils/LibClone.sol';

import { EpochFeeder } from '../../../src/hub/validator/EpochFeeder.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/validator/IEpochFeeder.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EpochFeederTest is Toolkit {
  using SafeCast for uint256;

  address owner = makeAddr('owner');

  EpochFeeder feeder;

  function setUp() public {
    feeder = EpochFeeder(
      address(
        new ERC1967Proxy(
          address(new EpochFeeder()), abi.encodeCall(EpochFeeder.initialize, (owner, Time.timestamp() + 1 days, 1 days))
        )
      )
    );
  }

  function test_init() public view {
    assertEq(feeder.owner(), owner);
    assertEq(feeder.epoch(), 1);
    assertEq(feeder.interval(), 1 days);
  }
}
