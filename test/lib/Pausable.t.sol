// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from '@std/Test.sol';

import { Pausable } from '../../src/lib/Pausable.sol';

contract PausableContract is Pausable {
  constructor() {
    __Pausable_init();
  }

  function pause() external {
    _pause();
  }

  function pause(bytes4 sig) external {
    _pause(sig);
  }

  function unpause() external {
    _unpause();
  }

  function unpause(bytes4 sig) external {
    _unpause(sig);
  }

  function assertNotPaused() external view {
    _assertNotPaused();
  }

  function assertNotPaused(bytes4 sig) external view {
    _assertNotPaused(sig);
  }

  function assertPaused() external view {
    _assertPaused();
  }

  function assertPaused(bytes4 sig) external view {
    _assertPaused(sig);
  }
}

contract PausableTest is Test {
  PausableContract internal _tester;

  function setUp() public {
    _tester = new PausableContract();
  }

  function test_normal() public {
    bytes4 sig = _sig('foo()');

    assertFalse(_tester.isPaused(sig));
    assertFalse(_tester.isPausedGlobally());

    _tester.pause();

    assertTrue(_tester.isPaused(sig));
    assertTrue(_tester.isPausedGlobally());

    _tester.pause(sig);

    assertTrue(_tester.isPaused(sig));
    assertTrue(_tester.isPausedGlobally());

    _tester.unpause();

    assertTrue(_tester.isPaused(sig));
    assertFalse(_tester.isPausedGlobally());

    _tester.unpause(sig);

    assertFalse(_tester.isPaused(sig));
    assertFalse(_tester.isPausedGlobally());
  }

  function _sig(string memory func) private pure returns (bytes4) {
    return bytes4(keccak256(bytes(func)));
  }
}
