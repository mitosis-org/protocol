// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from 'forge-std/Vm.sol';
import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {Placeholder} from '../src/Placeholder.sol';

contract TestPlaceholder is Test {
  Placeholder internal placeholder;

  function setUp() public {
    placeholder = new Placeholder();
  }

  function test_say() public view {
    string memory ask = 'hello';
    string memory result = placeholder.say(ask);

    console.log('result: %s', result);
    assertEq(result, 'hellohellohello');
  }
}
