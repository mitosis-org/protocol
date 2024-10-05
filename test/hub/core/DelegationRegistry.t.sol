// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { DelegationRegistry } from '../../../src/hub/core/DelegationRegistry.sol';

contract MockRedistributionRule { }

contract DelegationRegistryTest is Test {
  DelegationRegistry internal _delegationRegistry;
  ProxyAdmin internal _proxyAdmin;
  MockRedistributionRule internal _redistributionRule;

  address immutable owner = makeAddr('owner');
  address immutable user1 = makeAddr('user1');
  address immutable delegationManager = makeAddr('delegationManager');
  address immutable defaultDelegatee = makeAddr('defaultDelegatee');
  address immutable redistributionRule = makeAddr('redistributionRule');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    DelegationRegistry delgationRegistryImpl = new DelegationRegistry();
    _delegationRegistry = DelegationRegistry(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(delgationRegistryImpl),
            address(_proxyAdmin),
            abi.encodeCall(_delegationRegistry.initialize, (mitosis))
          )
        )
      )
    );

    _redistributionRule = new MockRedistributionRule();
  }

  function test_setDelegationManager() public {
    assertEq(_delegationRegistry.delegationManager(user1), user1);

    vm.prank(user1);
    _delegationRegistry.setDelegationManager(user1, delegationManager);

    assertEq(_delegationRegistry.delegationManager(user1), delegationManager);
  }

  function test_setDelegationManager_auth() public {
    test_setDelegationManager();

    vm.prank(delegationManager);
    _delegationRegistry.setDelegationManager(user1, address(1));

    assertEq(_delegationRegistry.delegationManager(user1), address(1));

    vm.prank(user1);
    _delegationRegistry.setDelegationManager(user1, address(3));

    assertEq(_delegationRegistry.delegationManager(user1), address(3));
  }

  function test_setDefaultDelegatee() public {
    assertEq(_delegationRegistry.defaultDelegatee(user1), address(0));

    vm.prank(user1);
    _delegationRegistry.setDefaultDelegatee(user1, defaultDelegatee);

    assertEq(_delegationRegistry.defaultDelegatee(user1), defaultDelegatee);
  }

  function test_setDefaultDelegatee_auth() public {
    vm.prank(user1);
    _delegationRegistry.setDelegationManager(user1, delegationManager);
    assertEq(_delegationRegistry.delegationManager(user1), delegationManager);

    vm.prank(delegationManager);
    _delegationRegistry.setDefaultDelegatee(user1, address(1));

    assertEq(_delegationRegistry.defaultDelegatee(user1), address(1));

    vm.prank(user1);
    _delegationRegistry.setDefaultDelegatee(user1, address(3));

    assertEq(_delegationRegistry.defaultDelegatee(user1), address(3));
  }
}
