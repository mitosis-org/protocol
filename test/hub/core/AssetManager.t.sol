// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Vm } from '@std/Vm.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { ERC20 } from '@oz-v5/token/ERC20/ERC20.sol';

import { AssetManager } from '../../../src/hub/core/AssetManager.sol';
import { AssetManagerStorageV1 } from '../../../src/hub/core/AssetManagerStorageV1.sol';
import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { OptOutQueue } from '../../../src/hub/eol/OptOutQueue.sol';
import { EOLVaultBasic } from '../../../src/hub/eol/vault/EOLVaultBasic.sol';
import { IAssetManager, IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../../src/interfaces/hub/core/IHubAsset.sol';
import { IERC20TWABSnapshots } from '../../../src/interfaces/twab/IERC20TWABSnapshots.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockAssetManagerEntrypoint } from '../../mock/MockAssetManagerEntrypoint.t.sol';
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';
import { MockRewardHandler } from '../../mock/MockRewardHandler.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockOptOutqueue { }

contract AssetManagerTest is Toolkit {
  OptOutQueue _optOutQueue;
  AssetManager _assetManager;
  MockRewardHandler _rewardHandler;
  MockAssetManagerEntrypoint _assetManagerEntrypoint;
  MockDelegationRegistry _delegationRegistry;
  EOLVaultBasic _eolVault;
  HubAsset _token;
  ProxyAdmin internal _proxyAdmin;

  address owner = makeAddr('owner');
  address user1 = makeAddr('user1');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  uint48 branchChainId = 10;
  address branchAsset1 = makeAddr('branchAsset1');
  address branchAsset2 = makeAddr('branchAsset2');
  address branchRewardTokenAddress = makeAddr('branchRewardTokenAddress');
  address strategist = makeAddr('strategist');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    OptOutQueue optOutQueueImpl = new OptOutQueue();
    _optOutQueue = OptOutQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(optOutQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(_optOutQueue.initialize, (owner, address(_proxyAdmin)))
          )
        )
      )
    );

    AssetManager assetManagerImpl = new AssetManager();
    _assetManager = AssetManager(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(assetManagerImpl), address(_proxyAdmin), abi.encodeCall(_assetManager.initialize, (owner))
          )
        )
      )
    );
    vm.prank(owner);
    _assetManager.setOptOutQueue(address(_optOutQueue));

    _rewardHandler = new MockRewardHandler();
    _assetManagerEntrypoint = new MockAssetManagerEntrypoint(_assetManager, address(0));
    _delegationRegistry = new MockDelegationRegistry(mitosis);

    HubAsset tokenImpl = new HubAsset();
    _token = HubAsset(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(tokenImpl),
            address(_proxyAdmin),
            abi.encodeCall(_token.initialize, (owner, address(_assetManager), address(_delegationRegistry), 'Token', 'TKN'))
          )
        )
      )
    );

    EOLVaultBasic eolVaultImpl = new EOLVaultBasic();
    _eolVault = EOLVaultBasic(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolVaultImpl),
            address(_proxyAdmin),
            abi.encodeCall(
              _eolVault.initialize,
              (address(_delegationRegistry), address(_assetManager), IERC20TWABSnapshots(address(_token)), '', '')
            )
          )
        )
      )
    );

    vm.startPrank(owner);
    _optOutQueue.setAssetManager(address(_assetManager));
    _assetManager.setEntrypoint(address(_assetManagerEntrypoint));
    vm.stopPrank();
  }

  function test_deposit() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);

    assertEq(_token.balanceOf(user1), 100 ether);
  }

  function test_deposit_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);
  }

  function test_deposit_BranchAssetPairNotExist() public {
    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errBranchAssetPairNotExist(branchAsset1));
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
    vm.stopPrank();

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.depositWithOptIn(branchChainId, branchAsset1, user1, address(_eolVault), 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_eolVault.balanceOf(user1), 100 ether);
  }

  function test_depositWithOptIn_Unauthorized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
    vm.stopPrank();

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.depositWithOptIn(branchChainId, branchAsset1, user1, address(_eolVault), 100 ether);
  }

  function test_depositWithOptIn_BranchAssetPairNotExist() public {
    // No occurrence case until methods like unsetAssetPair are added.
  }

  function test_depositWithOptIn_EOLNotInitialized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    // _assetManager.initializeEOL(branchChainId, address(_eolVault));
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errEOLNotInitialized(branchChainId, address(_eolVault)));
    _assetManager.depositWithOptIn(branchChainId, branchAsset1, user1, address(_eolVault), 100 ether);

    vm.stopPrank();
  }

  function test_depositWithOptIn_InvalidEOLVault() public {
    MockERC20TWABSnapshots myToken = new MockERC20TWABSnapshots();
    myToken.initialize(address(_delegationRegistry), 'Token', 'TKN');

    EOLVaultBasic eolVaultImpl = new EOLVaultBasic();
    EOLVaultBasic incorrectEOLVault = EOLVaultBasic(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolVaultImpl),
            address(_proxyAdmin),
            abi.encodeCall(
              _eolVault.initialize,
              (address(_delegationRegistry), address(_assetManager), IERC20TWABSnapshots(address(myToken)), '', '')
            )
          )
        )
      )
    );

    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    // add incorrect pair
    _assetManager.setAssetPair(address(myToken), branchChainId, branchAsset2);
    _assetManager.initializeEOL(branchChainId, address(incorrectEOLVault));
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errInvalidEOLVault(address(incorrectEOLVault), address(_token)));
    _assetManager.depositWithOptIn(branchChainId, branchAsset1, user1, address(incorrectEOLVault), 100 ether);

    vm.stopPrank();
  }

  function test_redeem() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);

    vm.prank(user1);
    _assetManager.redeem(branchChainId, address(_token), user1, 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_assetManager)), 0);
  }

  function test_redeem_Unauthorized() public {
    // TODO
  }

  function test_redeem_BranchAssetPairNotExist() public {
    // No occurrence case until methods like unsetAssetPair are added.
  }

  function test_redeem_ToZeroAddress() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);

    vm.startPrank(user1);

    vm.expectRevert(_errZeroToAddress());
    _assetManager.redeem(branchChainId, address(_token), address(0), 100 ether);

    vm.stopPrank();
  }

  function test_redeem_ZeroAmount() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId, branchAsset1, user1, 100 ether);

    vm.startPrank(user1);

    vm.expectRevert(_errZeroAmount());
    _assetManager.redeem(branchChainId, address(_token), user1, 0);

    vm.stopPrank();
  }

  function test_allocateEOL() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
    _assetManager.setStrategist(address(_eolVault), strategist);
    vm.stopPrank();

    vm.prank(address(_assetManager));
    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.prank(strategist);
    _assetManager.allocateEOL(branchChainId, address(_eolVault), 100 ether);

    assertEq(_assetManager.eolAlloc(address(_eolVault)), 100 ether);
    assertEq(_assetManager.eolIdle(address(_eolVault)), 0);
  }

  function test_allocateEOL_Unauthorized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
    _assetManager.setStrategist(address(_eolVault), strategist);
    vm.stopPrank();

    vm.prank(address(_assetManager));
    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.allocateEOL(branchChainId, address(_eolVault), 100 ether);
  }

  function test_allocateEOL_EOLNotInitialized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    // _assetManager.initializeEOL(branchChainId, address(_eolVault));
    _assetManager.setStrategist(address(_eolVault), strategist);
    vm.stopPrank();

    vm.prank(address(_assetManager));
    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.startPrank(strategist);

    vm.expectRevert(_errEOLNotInitialized(branchChainId, address(_eolVault)));
    _assetManager.allocateEOL(branchChainId, address(_eolVault), 100 ether);

    vm.stopPrank();
  }

  function test_allocateEOL_EOLInsufficient() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
    _assetManager.setStrategist(address(_eolVault), strategist);
    vm.stopPrank();

    vm.prank(address(_assetManager));
    _token.mint(user1, 100 ether);

    vm.startPrank(user1);

    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.startPrank(strategist);

    vm.expectRevert(_errEOLInsufficient(address(_eolVault)));
    _assetManager.allocateEOL(branchChainId, address(_eolVault), 101 ether);

    vm.stopPrank();
  }

  function test_deallocateEOL() public {
    test_allocateEOL();
    assertEq(_assetManager.eolIdle(address(_eolVault)), 0);
    assertEq(_assetManager.eolAlloc(address(_eolVault)), 100 ether);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deallocateEOL(branchChainId, address(_eolVault), 100 ether);

    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);
    assertEq(_assetManager.eolAlloc(address(_eolVault)), 0);
  }

  function test_deallocateEOL_Unauthorized() public {
    test_allocateEOL();
    assertEq(_assetManager.eolIdle(address(_eolVault)), 0);
    assertEq(_assetManager.eolAlloc(address(_eolVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.deallocateEOL(branchChainId, address(_eolVault), 100 ether);
  }

  function test_reserveEOL() public {
    test_deallocateEOL();
    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.prank(owner);
    _optOutQueue.enable(address(_eolVault));

    vm.prank(user1); // Resolve
    _eolVault.transfer(address(_optOutQueue), 10 ether);

    vm.prank(strategist);
    _assetManager.reserveEOL(address(_eolVault), 10 ether);

    assertEq(_eolVault.balanceOf(address(_optOutQueue)), 0);
    assertEq(_assetManager.eolIdle(address(_eolVault)), 90 ether);
  }

  function test_reserveEOL_Unauthorized() public {
    test_deallocateEOL();
    assertEq(_assetManager.eolIdle(address(_eolVault)), 100 ether);

    vm.prank(owner);
    _optOutQueue.enable(address(_eolVault));

    vm.prank(user1); // Resolve
    _eolVault.transfer(address(_optOutQueue), 10 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.reserveEOL(address(_eolVault), 10 ether);
  }

  function test_settleYield() public {
    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleYield(branchChainId, address(_eolVault), 100 ether);

    assertEq(_token.balanceOf(address(_assetManager)), 0);
  }

  function test_settleYield_Unauthorized() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleYield(branchChainId, address(_eolVault), 100 ether);
  }

  function test_settleLoss() public {
    test_deposit();
    assertEq(_token.balanceOf(user1), 100 ether);

    vm.startPrank(user1);
    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);
    vm.stopPrank();

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_eolVault)), 100 ether);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleLoss(branchChainId, address(_eolVault), 10 ether);

    assertEq(_token.balanceOf(address(_eolVault)), 100 ether - 10 ether);
  }

  function test_settleLoss_Unauthorized() public {
    test_deposit();
    assertEq(_token.balanceOf(user1), 100 ether);

    vm.startPrank(user1);
    _token.approve(address(_eolVault), 100 ether);
    _eolVault.deposit(100 ether, user1);
    vm.stopPrank();

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_eolVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleLoss(branchChainId, address(_eolVault), 10 ether);
  }

  function test_settleExtraRewards() public {
    MockERC20TWABSnapshots rewardToken = new MockERC20TWABSnapshots();
    rewardToken.initialize(address(_delegationRegistry), 'Reward', '$REWARD');

    vm.startPrank(owner);
    _assetManager.setRewardHandler(address(_rewardHandler));
    _assetManager.setAssetPair(address(rewardToken), branchChainId, branchRewardTokenAddress);
    vm.stopPrank();

    assertEq(rewardToken.totalSupply(), 0);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleExtraRewards(branchChainId, address(_eolVault), branchRewardTokenAddress, 100 ether);

    assertEq(rewardToken.totalSupply(), 100 ether);
  }

  function test_settleExtraRewards_Unauthorized() public {
    MockERC20TWABSnapshots rewardToken = new MockERC20TWABSnapshots();
    rewardToken.initialize(address(_delegationRegistry), 'Reward', '$REWARD');

    vm.startPrank(owner);
    _assetManager.setRewardHandler(address(_rewardHandler));
    _assetManager.setAssetPair(address(rewardToken), branchChainId, branchRewardTokenAddress);
    vm.stopPrank();

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleExtraRewards(branchChainId, address(_eolVault), branchRewardTokenAddress, 100 ether);
  }

  function test_settleExtraRewards_BranchAssetPairNotExist() public {
    vm.startPrank(owner);
    _assetManager.setRewardHandler(address(_rewardHandler));
    // _assetManager.setAssetPair(address(rewardToken), branchChainId, branchRewardTokenAddress);
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errBranchAssetPairNotExist(branchRewardTokenAddress));
    _assetManager.settleExtraRewards(branchChainId, address(_eolVault), branchRewardTokenAddress, 100 ether);

    vm.stopPrank();
  }

  function test_settleExtraRewards_EOLRewardRouterNotSet() public {
    MockERC20TWABSnapshots rewardToken = new MockERC20TWABSnapshots();
    rewardToken.initialize(address(_delegationRegistry), 'Reward', '$REWARD');

    vm.startPrank(owner);
    // _assetManager.setRewardHandler(address(_eolRewardManager));
    _assetManager.setAssetPair(address(rewardToken), branchChainId, branchRewardTokenAddress);
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errEOLRewardHandlerNotSet());
    _assetManager.settleExtraRewards(branchChainId, address(_eolVault), branchRewardTokenAddress, 100 ether);

    vm.stopPrank();
  }

  function test_initializeAsset() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(owner);
    _assetManager.initializeAsset(branchChainId, address(_token));

    assertEq(_assetManager.branchAsset(address(_token), branchChainId), branchAsset1);
  }

  function test_initializeAsset_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.initializeAsset(branchChainId, address(_token));
  }

  function test_initializeAsset_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('hubAsset'));
    _assetManager.initializeAsset(branchChainId, address(0));

    vm.stopPrank();
  }

  function test_initializeAsset_BranchAssetPairNotExist() public {
    vm.startPrank(owner);

    vm.expectRevert(_errBranchAssetPairNotExist(address(0)));
    _assetManager.initializeAsset(branchChainId, address(_token));

    vm.stopPrank();
  }

  function test_initializeEOL() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.prank(owner);
    _assetManager.initializeEOL(branchChainId, address(_eolVault));

    assertTrue(_assetManager.eolInitialized(branchChainId, address(_eolVault)));
  }

  function test_initializeEOL_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.initializeEOL(branchChainId, address(_eolVault));
  }

  function test_initializeEOL_InvalidParameter() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('eolVault'));
    _assetManager.initializeEOL(branchChainId, address(0));

    vm.stopPrank();
  }

  function test_initializeEOL_BranchAssetPairNotExist() public {
    vm.startPrank(owner);

    vm.expectRevert(_errBranchAssetPairNotExist(address(0)));
    _assetManager.initializeEOL(branchChainId, address(_eolVault));

    vm.stopPrank();
  }

  function test_initializeEOL_EOLAlreadyInitialized() public {
    test_initializeEOL();
    assertTrue(_assetManager.eolInitialized(branchChainId, address(_eolVault)));

    vm.startPrank(owner);

    vm.expectRevert(_errEOLAlreadyInitialized(branchChainId, address(_eolVault)));
    _assetManager.initializeEOL(branchChainId, address(_eolVault));

    vm.stopPrank();
  }

  function test_setAssetPair() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);

    assertEq(_assetManager.branchAsset(address(_token), branchChainId), branchAsset1);
  }

  function test_setAssetPair_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setAssetPair(address(_token), branchChainId, branchAsset1);
  }

  function test_setAssetPair_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('hubAsset'));
    _assetManager.setAssetPair(address(0), branchChainId, branchAsset1);

    vm.stopPrank();
  }

  function test_setEntrypoint() public {
    MockAssetManagerEntrypoint newAssetManagerEntrypoint = new MockAssetManagerEntrypoint(_assetManager, address(0));

    assertEq(_assetManager.entrypoint(), address(_assetManagerEntrypoint));

    vm.startPrank(owner);

    _assetManager.setEntrypoint(address(newAssetManagerEntrypoint));
    vm.stopPrank();

    assertEq(_assetManager.entrypoint(), address(newAssetManagerEntrypoint));
  }

  function test_setEntrypoint_Unauthorized() public {
    MockAssetManagerEntrypoint newAssetManagerEntrypoint = new MockAssetManagerEntrypoint(_assetManager, address(0));

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setEntrypoint(address(newAssetManagerEntrypoint));
  }

  function test_setEntrypoint_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('Entrypoint'));
    _assetManager.setEntrypoint(address(0));

    vm.stopPrank();
  }

  function test_setOptOutQueue() public {
    OptOutQueue optOutQueueImpl = new OptOutQueue();
    OptOutQueue newOptOutQueue = OptOutQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(optOutQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(OptOutQueue.initialize, (owner, address(_assetManager)))
          )
        )
      )
    );

    assertEq(_assetManager.optOutQueue(), address(_optOutQueue));

    vm.prank(owner);
    _assetManager.setOptOutQueue(address(newOptOutQueue));
    assertEq(_assetManager.optOutQueue(), address(newOptOutQueue));
  }

  function test_setOptOutQueue_Unauthorized() public {
    OptOutQueue optOutQueueImpl = new OptOutQueue();
    OptOutQueue newOptOutQueue = OptOutQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(optOutQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(OptOutQueue.initialize, (owner, address(_assetManager)))
          )
        )
      )
    );

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setOptOutQueue(address(newOptOutQueue));
  }

  function test_setOptOutQueue_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('OptOutQueue'));
    _assetManager.setOptOutQueue(address(0));

    vm.stopPrank();
  }

  function test_setRewardHandler() public {
    assertEq(_assetManager.rewardHandler(), address(0));

    vm.prank(owner);
    _assetManager.setRewardHandler(address(_rewardHandler));

    assertEq(_assetManager.rewardHandler(), address(_rewardHandler));

    MockRewardHandler newEOLRewardRouter = new MockRewardHandler();

    vm.prank(owner);
    _assetManager.setRewardHandler(address(newEOLRewardRouter));

    assertEq(_assetManager.rewardHandler(), address(newEOLRewardRouter));
  }

  function test_setRewardHandler_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setRewardHandler(address(_rewardHandler));
  }

  function test_setRewardHandler_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('RewardHandler'));
    _assetManager.setRewardHandler(address(0));

    vm.stopPrank();
  }

  function test_setStrategist() public {
    assertEq(_assetManager.strategist(address(_eolVault)), address(0));

    vm.prank(owner);
    _assetManager.setStrategist(address(_eolVault), strategist);

    assertEq(_assetManager.strategist(address(_eolVault)), strategist);

    address newStrategist = makeAddr('newStrategist');

    vm.prank(owner);
    _assetManager.setStrategist(address(_eolVault), newStrategist);

    assertEq(_assetManager.strategist(address(_eolVault)), newStrategist);
  }

  function test_setStrategist_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setStrategist(address(_eolVault), strategist);
  }

  function test_setStrategist_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('EOLVault'));
    _assetManager.setStrategist(address(0), strategist);

    vm.stopPrank();
  }

  function _errBranchAssetPairNotExist(address branchAsset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__BranchAssetPairNotExist.selector, branchAsset
    );
  }

  function _errEOLNotInitialized(uint256 chainId, address eolVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__EOLNotInitialized.selector, chainId, eolVault
    );
  }

  function _errEOLAlreadyInitialized(uint256 chainId, address eolVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__EOLAlreadyInitialized.selector, chainId, eolVault
    );
  }

  function _errInvalidEOLVault(address eolVault, address hubAsset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManager.IAssetManager__InvalidEOLVault.selector, eolVault, hubAsset);
  }

  function _errEOLInsufficient(address eolVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManager.IAssetManager__EOLInsufficient.selector, eolVault);
  }

  function _errEOLRewardHandlerNotSet() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManagerStorageV1.IAssetManagerStorageV1__RewardHandlerNotSet.selector);
  }
}
