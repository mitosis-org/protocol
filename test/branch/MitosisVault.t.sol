// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MitosisVault, AssetAction, EOLAction } from '../../src/branch/MitosisVault.sol';
import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { StdError } from '../../src/lib/StdError.sol';
import { MockDelegationRegistry } from '../mock/MockDelegationRegistry.t.sol';
import { MockEOLStrategyExecutor } from '../mock/MockEOLStrategyExecutor.t.sol';
import { MockERC20TWABSnapshots } from '../mock/MockERC20TWABSnapshots.t.sol';
import { MockMitosisVaultEntrypoint } from '../mock/MockMitosisVaultEntrypoint.t.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract MitosisVaultTest is Toolkit {
  MitosisVault _mitosisVault;
  MockMitosisVaultEntrypoint _mitosisVaultEntrypoint;
  ProxyAdmin _proxyAdmin;
  MockERC20TWABSnapshots _token;
  MockEOLStrategyExecutor _eolStrategyExecutor;
  MockDelegationRegistry _delegationRegistry;

  address immutable owner = makeAddr('owner');
  address immutable hubEOLVault = makeAddr('hubEOLVault');

  function setUp() public {
    _delegationRegistry = new MockDelegationRegistry();
    _proxyAdmin = new ProxyAdmin(owner);

    MitosisVault mitosisVaultImpl = new MitosisVault();
    _mitosisVault = MitosisVault(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(mitosisVaultImpl), address(_proxyAdmin), abi.encodeCall(mitosisVaultImpl.initialize, (owner))
          )
        )
      )
    );

    _mitosisVaultEntrypoint = new MockMitosisVaultEntrypoint();

    _token = new MockERC20TWABSnapshots();
    _token.initialize(address(_delegationRegistry), 'Token', 'TKN');

    _eolStrategyExecutor = new MockEOLStrategyExecutor(_mitosisVault, _token, hubEOLVault);

    vm.prank(owner);
    _mitosisVault.setEntrypoint(_mitosisVaultEntrypoint);
  }

  function test_initializeAsset() public {
    assertFalse(_mitosisVault.isAssetInitialized(address(_token)));

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    assertTrue(_mitosisVault.isAssetInitialized(address(_token)));
  }

  function test_initializeAsset_Unauthorized() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.initializeAsset(address(_token));

    vm.startPrank(owner);
    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.initializeAsset(address(_token));
    vm.stopPrank();
  }

  function test_initializeAsset_AssetAlreadyInitialized() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    assertTrue(_mitosisVault.isAssetInitialized(address(_token)));

    vm.expectRevert(_errAssetAlreadyInitialized(address(_token)));
    _mitosisVault.initializeAsset(address(_token));

    vm.stopPrank();
  }

  function test_deposit() public {
    address user1 = makeAddr('user1');
    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);
    _mitosisVault.deposit(address(_token), user1, 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.stopPrank();
  }

  function test_deposit_AssetNotInitialized() public {
    address user1 = makeAddr('user1');
    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errAssetNotInitialized(address(_token)));
    _mitosisVault.deposit(address(_token), user1, 100 ether);

    vm.stopPrank();
  }

  function test_deposit_AssetHalted() public {
    address user1 = makeAddr('user1');
    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(StdError.Halted.selector);
    _mitosisVault.deposit(address(_token), user1, 100 ether);

    vm.stopPrank();
  }

  function test_deposit_ZeroAddress() public {
    address user1 = makeAddr('user1');
    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errZeroToAddress());
    _mitosisVault.deposit(address(_token), address(0), 100 ether);

    vm.stopPrank();
  }

  function test_deposit_ZeroAmount() public {
    address user1 = makeAddr('user1');
    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 0);

    vm.expectRevert(StdError.ZeroAmount.selector);
    _mitosisVault.deposit(address(_token), user1, 0);

    vm.stopPrank();
  }

  function test_depositWithOptIn() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    // TODO: resumeEOL check?

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);
    _mitosisVault.depositWithOptIn(address(_token), user1, hubEOLVault, 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_AssetNotInitialized() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errAssetNotInitialized(address(_token)));
    _mitosisVault.depositWithOptIn(address(_token), user1, hubEOLVault, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_AssetHalted() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(StdError.Halted.selector);
    _mitosisVault.depositWithOptIn(address(_token), user1, hubEOLVault, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_EOLNotInitialized() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    // vm.prank(address(_mitosisVaultEntrypoint));
    // _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errEOLNotInitiailized(hubEOLVault));
    _mitosisVault.depositWithOptIn(address(_token), user1, hubEOLVault, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_ZeroAddress() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errZeroToAddress());
    _mitosisVault.depositWithOptIn(address(_token), address(0), hubEOLVault, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_ZeroAmount() public {
    address user1 = makeAddr('user1');

    _token.mint(user1, 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.prank(owner);
    _mitosisVault.resumeAsset(address(_token), AssetAction.Deposit);

    vm.startPrank(user1);

    _token.approve(address(_mitosisVault), 0);

    vm.expectRevert(StdError.ZeroAmount.selector);
    _mitosisVault.depositWithOptIn(address(_token), user1, hubEOLVault, 0);

    vm.stopPrank();
  }

  function test_redeem() public {
    test_deposit(); // (owner) - - - deposit 100 ETH - - -> (_mitosisVault)
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.redeem(address(_token), address(1), 10 ether);

    assertEq(_token.balanceOf(address(1)), 10 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 90 ether);
  }

  function test_redeem_Unauthorized() public {
    test_deposit();
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.redeem(address(_token), address(1), 10 ether);
  }

  function test_redeem_AssetNotInitialized() public {
    test_deposit();
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.startPrank(address(_mitosisVaultEntrypoint));

    address myToken = address(10);

    vm.expectRevert(_errAssetNotInitialized(myToken));
    _mitosisVault.redeem(myToken, address(1), 10 ether);

    vm.stopPrank();
  }

  function test_redeem_NotEnoughBalance() public {
    test_deposit();
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.startPrank(address(_mitosisVaultEntrypoint));

    vm.expectRevert();
    _mitosisVault.redeem(address(_token), address(1), 101 ether);

    vm.stopPrank();
  }

  function test_initializeEOL() public {
    assertFalse(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.startPrank(address(_mitosisVaultEntrypoint));

    _mitosisVault.initializeAsset(address(_token));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.stopPrank();

    assertTrue(_mitosisVault.isAssetInitialized(address(_token)));
  }

  function test_initializeEOL_Unauthorized() public {
    assertFalse(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));
  }

  function test_initializeEOL_EOLAlreadyInitialized() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.startPrank(address(_mitosisVaultEntrypoint));

    vm.expectRevert(_errEOLAlreadyInitialized(hubEOLVault));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.stopPrank();
  }

  function test_initializeEOL_AssetNotInitialized() public {
    assertFalse(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.startPrank(address(_mitosisVaultEntrypoint));

    // _mitosisVault.initializeAsset(address(_token));
    vm.expectRevert(_errAssetNotInitialized(address(_token)));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.stopPrank();
  }

  function test_allocateEOL() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));

    _mitosisVault.initializeAsset(address(_token));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    _mitosisVault.allocateEOL(hubEOLVault, 100 ether);

    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);

    vm.stopPrank();
  }

  function test_allocateEOL_Unauthorized() public {
    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));
  }

  function test_allocateEOL_EOLNotInitialized() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));

    _mitosisVault.initializeAsset(address(_token));

    // _mitosisVault.initializeEOL(hubEOLVault, address(_token));

    vm.expectRevert(_errEOLNotInitiailized(hubEOLVault));
    _mitosisVault.allocateEOL(hubEOLVault, 100 ether);

    vm.stopPrank();
  }

  function test_deallocateEOL() public {
    test_allocateEOL();
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.prank(address(_eolStrategyExecutor));
    _mitosisVault.deallocateEOL(hubEOLVault, 10 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 90 ether);

    vm.prank(address(_eolStrategyExecutor));
    _mitosisVault.deallocateEOL(hubEOLVault, 90 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 0 ether);
  }

  function test_deallocateEOL_Unauthorized() public {
    test_allocateEOL();
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.deallocateEOL(hubEOLVault, 10 ether);
  }

  function test_deallocateEOL_InsufficientEOL() public {
    test_allocateEOL();
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.expectRevert();
    _mitosisVault.deallocateEOL(hubEOLVault, 101 ether);
  }

  function test_fetchEOL() public {
    test_allocateEOL();
    _token.mint(address(_mitosisVault), 100 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.startPrank(address(_eolStrategyExecutor));
    _mitosisVault.fetchEOL(hubEOLVault, 10 ether);
    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), 10 ether);

    _mitosisVault.fetchEOL(hubEOLVault, 90 ether);
    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), 100 ether);

    vm.stopPrank();
  }

  function test_fetchEOL_EOLNotInitialized() public {
    // No occurrence case until methods like deinitializeEOL are added.
  }

  function test_fetchEOL_Unauthorized() public {
    test_allocateEOL();
    _token.mint(address(_mitosisVault), 100 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.fetchEOL(hubEOLVault, 10 ether);
  }

  function test_fetchEOL_AssetHalted() public {
    test_allocateEOL();
    _token.mint(address(_mitosisVault), 100 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.prank(owner);
    _mitosisVault.haltEOL(hubEOLVault, EOLAction.FetchEOL);

    vm.startPrank(address(_eolStrategyExecutor));

    vm.expectRevert(StdError.Halted.selector);
    _mitosisVault.fetchEOL(hubEOLVault, 10 ether);

    vm.stopPrank();
  }

  function test_fetchEOL_InsufficientEOL() public {
    test_allocateEOL();
    _token.mint(address(_mitosisVault), 100 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.startPrank(address(_eolStrategyExecutor));

    vm.expectRevert();
    _mitosisVault.fetchEOL(hubEOLVault, 101 ether);

    vm.stopPrank();
  }

  function test_returnEOL() public {
    test_fetchEOL();
    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 0);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 0);

    vm.startPrank(address(_eolStrategyExecutor));

    _token.approve(address(_mitosisVault), 100 ether);
    _mitosisVault.returnEOL(hubEOLVault, 100 ether);

    assertEq(_token.balanceOf(address(_mitosisVault)), 100 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 100 ether);

    vm.stopPrank();
  }

  function test_returnEOL_EOLNotInitialized() public {
    // No occurrence case until methods like deinitializeEOL are added.
  }

  function test_returnEOL_Unauthorized() public {
    test_fetchEOL();
    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), 100 ether);
    assertEq(_token.balanceOf(address(_mitosisVault)), 0);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 0);

    vm.prank(address(_eolStrategyExecutor));
    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.returnEOL(hubEOLVault, 100 ether);
  }

  function test_settleYield() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.prank(address(_eolStrategyExecutor));
    _mitosisVault.settleYield(hubEOLVault, 100 ether);
  }

  function test_settleYield_EOLNotInitialized() public {
    // No occurrence case until methods like deinitializeEOL are added.
  }

  function test_settleYield_Unauthorized() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.settleYield(hubEOLVault, 100 ether);
  }

  function test_settleLoss() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.prank(address(_eolStrategyExecutor));
    _mitosisVault.settleLoss(hubEOLVault, 100 ether);
  }

  function test_settleLoss_EOLNotInitialized() public {
    // No occurrence case until methods like deinitializeEOL are added.
  }

  function test_settleLoss_Unauthorized() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.settleLoss(hubEOLVault, 100 ether);
  }

  function test_settleExtraRewards() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(reward));

    vm.startPrank(address(_eolStrategyExecutor));

    reward.mint(address(_eolStrategyExecutor), 100 ether);
    reward.approve(address(_mitosisVault), 100 ether);

    _mitosisVault.settleExtraRewards(hubEOLVault, address(reward), 100 ether);

    vm.stopPrank();
  }

  function test_settleExtraRewards_EOLNotInitialized() public {
    // No occurrence case until methods like deinitializeEOL are added.
  }

  function test_settleExtraRewards_Unauthorized() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(reward));

    reward.mint(address(_eolStrategyExecutor), 100 ether);

    vm.prank(address(_eolStrategyExecutor));
    reward.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _mitosisVault.settleExtraRewards(hubEOLVault, address(reward), 100 ether);
  }

  function test_settleExtraRewards_AssetNotInitialized() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    // vm.prank(address(_mitosisVaultEntrypoint));
    // _mitosisVault.initializeAsset(address(reward));

    vm.startPrank(address(_eolStrategyExecutor));

    reward.mint(address(_eolStrategyExecutor), 100 ether);
    reward.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errAssetNotInitialized(address(reward)));
    _mitosisVault.settleExtraRewards(hubEOLVault, address(reward), 100 ether);

    vm.stopPrank();
  }

  function test_settleExtraRewards_InvalidRewardAddress() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.startPrank(address(_eolStrategyExecutor));

    _token.mint(address(_eolStrategyExecutor), 100 ether);
    _token.approve(address(_mitosisVault), 100 ether);

    vm.expectRevert(_errInvalidAddress('reward'));
    _mitosisVault.settleExtraRewards(hubEOLVault, address(_token), 100 ether);

    vm.stopPrank();
  }

  function test_setEntrypoint_Unauthorized() public {
    vm.expectRevert();
    _mitosisVault.setEntrypoint(IMitosisVaultEntrypoint(address(0)));
  }

  function test_setEOLStrategyExecutor() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));
  }

  function test_setEOLStrategyExecutor_EOLNotInitialized() public {
    vm.startPrank(owner);

    vm.expectRevert(_errEOLNotInitiailized(hubEOLVault));
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.stopPrank();
  }

  function test_setEOLStrategyExecutor_EOLStrategyExecutorNotDrained() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    _token.mint(address(_eolStrategyExecutor), 100 ether);
    assertTrue(_eolStrategyExecutor.totalBalance() > 0);

    MockEOLStrategyExecutor newEOLStrategyExecutor = new MockEOLStrategyExecutor(_mitosisVault, _token, hubEOLVault);

    vm.startPrank(owner);

    vm.expectRevert(_errEOLStrategyExecutorNotDraind(hubEOLVault, address(_eolStrategyExecutor)));
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(newEOLStrategyExecutor));

    vm.stopPrank();

    vm.prank(address(_eolStrategyExecutor));
    _token.transfer(address(1), 100 ether);

    assertEq(_eolStrategyExecutor.totalBalance(), 0);

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(newEOLStrategyExecutor));

    assertEq(_mitosisVault.eolStrategyExecutor(hubEOLVault), address(newEOLStrategyExecutor));
  }

  function test_setEOLStrategyExecutor_InvalidVaultAddress() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    MockEOLStrategyExecutor newEOLStrategyExecutor =
      new MockEOLStrategyExecutor(IMitosisVault(address(0)), _token, hubEOLVault);

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidAddress('eolStrategyExecutor.vault'));
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(newEOLStrategyExecutor));

    vm.stopPrank();
  }

  function test_setEOLStrategyExecutor_InvalidAssetAddress() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    MockEOLStrategyExecutor newEOLStrategyExecutor =
      new MockEOLStrategyExecutor(_mitosisVault, IERC20(address(0)), hubEOLVault);

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidAddress('eolStrategyExecutor.asset'));
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(newEOLStrategyExecutor));

    vm.stopPrank();
  }

  function test_setEOLStrategyExecutor_InvalidHubEOLVault() public {
    test_initializeEOL();
    assertTrue(_mitosisVault.isEOLInitialized(hubEOLVault));

    MockEOLStrategyExecutor newEOLStrategyExecutor;
    newEOLStrategyExecutor = new MockEOLStrategyExecutor(_mitosisVault, _token, address(0));

    vm.startPrank(owner);

    vm.expectRevert();
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(newEOLStrategyExecutor));

    newEOLStrategyExecutor = new MockEOLStrategyExecutor(_mitosisVault, _token, hubEOLVault);

    vm.expectRevert();
    _mitosisVault.setEOLStrategyExecutor(address(0), address(newEOLStrategyExecutor));

    vm.stopPrank();
  }

  function _errAssetAlreadyInitialized(address asset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IMitosisVault.IMitosisVault__AssetAlreadyInitialized.selector, asset);
  }

  function _errAssetNotInitialized(address asset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IMitosisVault.IMitosisVault__AssetNotInitialized.selector, asset);
  }

  function _errEOLAlreadyInitialized(address _hubEOLVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IMitosisVault.IMitosisVault__EOLAlreadyInitialized.selector, _hubEOLVault);
  }

  function _errEOLNotInitiailized(address _hubEOLVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IMitosisVault.IMitosisVault__EOLNotInitialized.selector, _hubEOLVault);
  }

  function _errEOLStrategyExecutorNotDraind(address _hubEOLVault, address eolStrategyExecutor_)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      IMitosisVault.IMitosisVault__EOLStrategyExecutorNotDrained.selector, _hubEOLVault, eolStrategyExecutor_
    );
  }
}
