// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { Toolkit } from '../util/Toolkit.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { LibRedeemQueue } from '../../src/lib/LibRedeemQueue.sol';

contract LibRedeemQueueTest is Toolkit {
  using LibRedeemQueue for *;
  using LibString for *;

  function setUp() public { }
}
