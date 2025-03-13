// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { WETH } from '@solady/tokens/WETH.sol';

import { ValidatorStaking } from '../../../src/hub/validator/ValidatorStaking.sol';
import { IValidatorManager } from '../../../src/interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorStaking } from '../../../src/interfaces/hub/validator/IValidatorStaking.sol';
import { IValidatorStakingHub } from '../../../src/interfaces/hub/validator/IValidatorStakingHub.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorStakingTest is Toolkit {
  address owner = makeAddr('owner');
  address val1 = makeAddr('val1');
  address val2 = makeAddr('val2');
  address val3 = makeAddr('val3');
  address user1 = makeAddr('user1');
  address user2 = makeAddr('user2');

  WETH weth;
  MockContract hub;
  MockContract manager;

  ValidatorStaking erc20Vault;
  ValidatorStaking nativeVault;

  function setUp() public {
    weth = new WETH();
    hub = new MockContract();
    hub.setCall(IValidatorStakingHub.notifyStake.selector);
    hub.setCall(IValidatorStakingHub.notifyUnstake.selector);
    hub.setCall(IValidatorStakingHub.notifyRedelegation.selector);

    manager = new MockContract();

    erc20Vault = ValidatorStaking(
      payable(
        _proxy(
          address(
            new ValidatorStaking(
              address(weth), // erc20
              IValidatorManager(address(manager)),
              IValidatorStakingHub(address(hub))
            )
          ),
          abi.encodeCall(ValidatorStaking.initialize, (owner, 1 days, 1 days))
        )
      )
    );

    nativeVault = ValidatorStaking(
      payable(
        _proxy(
          address(
            new ValidatorStaking(
              address(0), // native
              IValidatorManager(address(manager)),
              IValidatorStakingHub(address(hub))
            )
          ),
          abi.encodeCall(ValidatorStaking.initialize, (owner, 1 days, 1 days))
        )
      )
    );
  }

  function test_init() public view {
    assertEq(erc20Vault.owner(), owner);
    assertEq(erc20Vault.baseAsset(), address(weth));
    assertEq(address(erc20Vault.manager()), address(manager));
    assertEq(address(erc20Vault.hub()), address(hub));
    assertEq(erc20Vault.unstakeCooldown(), 1 days);
    assertEq(erc20Vault.redelegationCooldown(), 1 days);

    assertEq(nativeVault.owner(), owner);
    assertEq(nativeVault.baseAsset(), nativeVault.NATIVE_TOKEN());
    assertEq(address(nativeVault.manager()), address(manager));
    assertEq(address(nativeVault.hub()), address(hub));
    assertEq(nativeVault.unstakeCooldown(), 1 days);
    assertEq(nativeVault.redelegationCooldown(), 1 days);
  }

  function test_stake() public {
    _test_stake(erc20Vault);
    _test_stake(nativeVault);
  }

  function _test_stake(ValidatorStaking vault) private {
    _fund();

    _regVal(val1, true);
    _regVal(val2, false);
    _regVal(val3, true);

    // ===== not a validator

    if (vault.baseAsset() == vault.NATIVE_TOKEN()) {
      vm.prank(user1);
      vm.expectRevert(IValidatorStaking.IValidatorStaking__NotValidator.selector);
      vault.stake{ value: 10 ether }(val2, user1, 10 ether);
    } else {
      vm.prank(user1);
      vm.expectRevert(IValidatorStaking.IValidatorStaking__NotValidator.selector);
      vault.stake(val2, user1, 10 ether);
    }

    // =====

    _stake(vault, val1, user1, user1, 10 ether);
    _stake(vault, val1, user2, user2, 20 ether);

    vm.warp(block.timestamp + 1 days);

    _stake(vault, val1, user1, user1, 20 ether);
    _stake(vault, val3, user2, user2, 10 ether);

    // =====

    uint48 now_ = _now48();

    //======== present

    assertEq(vault.totalStaked(now_), 60 ether);

    // user 1
    assertEq(vault.staked(val1, user1, now_), 30 ether);
    assertEq(vault.staked(val3, user1, now_), 0 ether);
    assertEq(vault.stakerTotal(user1, now_), 30 ether);

    // user 2
    assertEq(vault.staked(val1, user2, now_), 20 ether);
    assertEq(vault.staked(val3, user2, now_), 10 ether);
    assertEq(vault.stakerTotal(user2, now_), 30 ether);

    // vals
    assertEq(vault.validatorTotal(val1, now_), 50 ether);
    assertEq(vault.validatorTotal(val3, now_), 10 ether);

    //======== past

    assertEq(vault.totalStaked(now_ - 1), 30 ether);

    // user 1
    assertEq(vault.staked(val1, user1, now_ - 1), 10 ether);
    assertEq(vault.staked(val3, user1, now_ - 1), 0 ether);
    assertEq(vault.stakerTotal(user1, now_ - 1), 10 ether);

    // user 2
    assertEq(vault.staked(val1, user2, now_ - 1), 20 ether);
    assertEq(vault.staked(val3, user2, now_ - 1), 0 ether);
    assertEq(vault.stakerTotal(user2, now_ - 1), 20 ether);

    // vals
    assertEq(vault.validatorTotal(val1, now_ - 1), 30 ether);
    assertEq(vault.validatorTotal(val3, now_ - 1), 0 ether);
  }

  function _fund() internal {
    vm.deal(user1, 100 ether);
    vm.deal(user2, 100 ether);

    // pre-mint

    vm.prank(user1);
    weth.deposit{ value: 50 ether }();

    vm.prank(user2);
    weth.deposit{ value: 50 ether }();

    // pre-approve

    vm.prank(user1);
    weth.approve(address(erc20Vault), 50 ether);

    vm.prank(user2);
    weth.approve(address(erc20Vault), 50 ether);
  }

  function _stake(ValidatorStaking vault, address val, address sender, address recipient, uint256 amount) internal {
    if (vault.baseAsset() == vault.NATIVE_TOKEN()) {
      vm.prank(sender);
      vault.stake{ value: amount }(val, recipient, amount);
    } else {
      vm.prank(sender);
      vault.stake(val, recipient, amount);
    }

    hub.assertLastCall(IValidatorStakingHub.notifyStake.selector, abi.encode(val, recipient, amount));
  }

  function _regVal(address val, bool ok) internal {
    manager.setRet(IValidatorManager.isValidator.selector, abi.encode(val), false, abi.encode(ok));
  }
}
