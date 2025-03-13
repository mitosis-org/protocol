// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ValidatorStakingHub } from '../../../src/hub/validator/ValidatorStakingHub.sol';
import { IConsensusValidatorEntrypoint } from
  '../../../src/interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IValidatorStakingHub } from '../../../src/interfaces/hub/validator/IValidatorStakingHub.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorStakingHubTest is Toolkit {
  address owner = makeAddr('owner');
  address val1 = makeAddr('val-1');
  address val2 = makeAddr('val-2');
  address user1 = makeAddr('user-1');
  address user2 = makeAddr('user-2');
  address notifier1 = makeAddr('notifier-1');
  address notifier2 = makeAddr('notifier-2');

  MockContract entrypoint;
  ValidatorStakingHub hub;

  function setUp() public {
    entrypoint = new MockContract();
    hub = ValidatorStakingHub(
      _proxy(
        address(new ValidatorStakingHub(IConsensusValidatorEntrypoint(address(entrypoint)))),
        abi.encodeCall(ValidatorStakingHub.initialize, (owner))
      )
    );
  }

  function test_init() public view {
    assertEq(hub.owner(), owner);
    assertEq(address(hub.entrypoint()), address(entrypoint));
  }

  function test_addNotifier() public {
    assertFalse(hub.isNotifier(notifier1));
    assertFalse(hub.isNotifier(notifier2));

    vm.prank(owner);
    hub.addNotifier(notifier1);

    vm.prank(owner);
    hub.addNotifier(notifier2);

    assertTrue(hub.isNotifier(notifier1));
    assertTrue(hub.isNotifier(notifier2));
  }

  function test_removeNotifier() public {
    test_addNotifier();

    vm.prank(owner);
    hub.removeNotifier(notifier1);

    vm.prank(owner);
    hub.removeNotifier(notifier2);

    assertFalse(hub.isNotifier(notifier1));
    assertFalse(hub.isNotifier(notifier2));
  }

  function test_notifyStake() public {
    test_addNotifier();

    vm.prank(makeAddr('wrong'));
    vm.expectRevert(_errUnauthorized());
    hub.notifyStake(val1, user1, 10 ether);

    vm.startPrank(notifier1);
    hub.notifyStake(val1, user1, 10 ether);
    hub.notifyStake(val1, user2, 10 ether);
    vm.stopPrank();

    vm.warp(_now48() + 2);

    vm.startPrank(notifier2);
    hub.notifyStake(val2, user1, 10 ether);
    hub.notifyStake(val2, user2, 10 ether);
    vm.stopPrank();

    assertEq(hub.stakerTotal(user1, _now48()), 20 ether);
    assertEq(hub.stakerTotal(user2, _now48()), 20 ether);
    assertEq(hub.stakerTotal(user1, _now48() - 1), 10 ether);
    assertEq(hub.stakerTotal(user2, _now48() - 1), 10 ether);

    assertEq(hub.validatorTotal(val1, _now48()), 20 ether);
    assertEq(hub.validatorTotal(val2, _now48()), 20 ether);
    assertEq(hub.validatorTotal(val1, _now48() - 1), 20 ether);
    assertEq(hub.validatorTotal(val2, _now48() - 1), 0);

    assertEq(hub.validatorStakerTotal(val1, user1, _now48()), 10 ether);
    assertEq(hub.validatorStakerTotal(val1, user2, _now48()), 10 ether);
    assertEq(hub.validatorStakerTotal(val2, user1, _now48()), 10 ether);
    assertEq(hub.validatorStakerTotal(val2, user2, _now48()), 10 ether);

    assertEq(hub.validatorStakerTotal(val1, user1, _now48() - 1), 10 ether);
    assertEq(hub.validatorStakerTotal(val1, user2, _now48() - 1), 0);
    assertEq(hub.validatorStakerTotal(val2, user1, _now48() - 1), 10 ether);
    assertEq(hub.validatorStakerTotal(val2, user2, _now48() - 1), 0);
  }

  function test_notifyUnstake() public {
    test_addNotifier();

    vm.prank(makeAddr('wrong'));
    vm.expectRevert(_errUnauthorized());
    hub.notifyUnstake(val1, user1, 10 ether);
  }

  function test_notifyRedelegation() public {
    test_addNotifier();

    vm.prank(makeAddr('wrong'));
    vm.expectRevert(_errUnauthorized());
    hub.notifyRedelegation(val1, val2, user1, 10 ether);
  }
}
