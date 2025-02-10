// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { ERC20 } from '@oz-v5/token/ERC20/ERC20.sol';

import { AssetManager } from '../../../src/hub/core/AssetManager.sol';
import { AssetManagerStorageV1 } from '../../../src/hub/core/AssetManagerStorageV1.sol';
import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { ReclaimQueue } from '../../../src/hub/matrix/ReclaimQueue.sol';
import { Treasury } from '../../../src/hub/reward/Treasury.sol';
import { IAssetManager, IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IHubAsset } from '../../../src/interfaces/hub/core/IHubAsset.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockAssetManagerEntrypoint } from '../../mock/MockAssetManagerEntrypoint.t.sol';
import { MockERC20Snapshots } from '../../mock/MockERC20Snapshots.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockReclaimQueue { }

contract AssetManagerTest is Toolkit {
  ReclaimQueue _reclaimQueue;
  AssetManager _assetManager;
  Treasury _treasury;
  MockAssetManagerEntrypoint _assetManagerEntrypoint;
  MatrixVaultBasic _matrixVault;
  HubAsset _token;
  ProxyAdmin internal _proxyAdmin;

  address owner = makeAddr('owner');
  address user1 = makeAddr('user1');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  uint48 branchChainId1 = 10;
  uint48 branchChainId2 = 20;
  address branchAsset1 = makeAddr('branchAsset1');
  address branchAsset2 = makeAddr('branchAsset2');
  address branchRewardTokenAddress = makeAddr('branchRewardTokenAddress');
  address strategist = makeAddr('strategist');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    ReclaimQueue reclaimQueueImpl = new ReclaimQueue();
    _reclaimQueue = ReclaimQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(reclaimQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(_reclaimQueue.initialize, (owner, address(_proxyAdmin)))
          )
        )
      )
    );

    Treasury treasuryImpl = new Treasury();
    _treasury = Treasury(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(treasuryImpl), address(_proxyAdmin), abi.encodeCall(_treasury.initialize, (owner))
          )
        )
      )
    );

    AssetManager assetManagerImpl = new AssetManager();
    _assetManager = AssetManager(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(assetManagerImpl),
            address(_proxyAdmin),
            abi.encodeCall(_assetManager.initialize, (owner, address(_treasury)))
          )
        )
      )
    );

    vm.startPrank(owner);
    _treasury.grantRole(_treasury.TREASURY_MANAGER_ROLE(), address(_assetManager));
    _assetManager.setReclaimQueue(address(_reclaimQueue));
    vm.stopPrank();

    _assetManagerEntrypoint = new MockAssetManagerEntrypoint(_assetManager, address(0));

    HubAsset tokenImpl = new HubAsset();
    _token = HubAsset(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(tokenImpl),
            address(_proxyAdmin),
            abi.encodeCall(_token.initialize, (owner, address(_assetManager), 'Token', 'TKN', 18))
          )
        )
      )
    );

    MatrixVaultBasic matrixVaultImpl = new MatrixVaultBasic();
    _matrixVault = MatrixVaultBasic(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(matrixVaultImpl),
            address(_proxyAdmin),
            abi.encodeCall(_matrixVault.initialize, (address(_assetManager), IERC20Metadata(address(_token)), '', ''))
          )
        )
      )
    );

    vm.startPrank(owner);
    _reclaimQueue.setAssetManager(address(_assetManager));
    _assetManager.setEntrypoint(address(_assetManagerEntrypoint));
    vm.stopPrank();
  }

  function test_deposit() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);

    assertEq(_token.balanceOf(user1), 100 ether);
  }

  function test_deposit_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);
  }

  function test_deposit_BranchAssetPairNotExist() public {
    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errBranchAssetPairNotExist(branchAsset1));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);

    vm.stopPrank();
  }

  function test_depositWithSupplyMatrix() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    vm.stopPrank();

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.depositWithSupplyMatrix(branchChainId1, branchAsset1, user1, address(_matrixVault), 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_matrixVault.balanceOf(user1), 100 ether);
  }

  function test_depositWithSupplyMatrix_Unauthorized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    vm.stopPrank();

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.depositWithSupplyMatrix(branchChainId1, branchAsset1, user1, address(_matrixVault), 100 ether);
  }

  function test_depositWithSupplyMatrix_BranchAssetPairNotExist() public {
    // No occurrence case until methods like unsetAssetPair are added.
  }

  function test_depositWithSupplyMatrix_MatrixNotInitialized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    // _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errMatrixNotInitialized(branchChainId1, address(_matrixVault)));
    _assetManager.depositWithSupplyMatrix(branchChainId1, branchAsset1, user1, address(_matrixVault), 100 ether);

    vm.stopPrank();
  }

  function test_depositWithSupplyMatrix_InvalidMatrixVault() public {
    MockERC20Snapshots myToken = new MockERC20Snapshots();
    myToken.initialize('Token', 'TKN');

    MatrixVaultBasic matrixVaultImpl = new MatrixVaultBasic();
    MatrixVaultBasic incorrectMatrixVault = MatrixVaultBasic(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(matrixVaultImpl),
            address(_proxyAdmin),
            abi.encodeCall(_matrixVault.initialize, (address(_assetManager), IERC20Metadata(address(myToken)), '', ''))
          )
        )
      )
    );

    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    // add incorrect pair
    _assetManager.setAssetPair(address(myToken), branchChainId1, branchAsset2);
    _assetManager.initializeMatrix(branchChainId1, address(incorrectMatrixVault));
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errInvalidMatrixVault(address(incorrectMatrixVault), address(_token)));
    _assetManager.depositWithSupplyMatrix(branchChainId1, branchAsset1, user1, address(incorrectMatrixVault), 100 ether);

    vm.stopPrank();
  }

  function test_redeem() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(owner);
    _assetManager.setHubAssetRedeemStatus(branchChainId1, address(_token), true);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);

    vm.prank(user1);
    _assetManager.redeem(branchChainId1, address(_token), user1, 100 ether);

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
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(owner);
    _assetManager.setHubAssetRedeemStatus(branchChainId1, address(_token), true);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);

    vm.startPrank(user1);

    vm.expectRevert(_errZeroToAddress());
    _assetManager.redeem(branchChainId1, address(_token), address(0), 100 ether);

    vm.stopPrank();
  }

  function test_redeem_ZeroAmount() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(owner);
    _assetManager.setHubAssetRedeemStatus(branchChainId1, address(_token), true);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);

    vm.startPrank(user1);

    vm.expectRevert(_errZeroAmount());
    _assetManager.redeem(branchChainId1, address(_token), user1, 0);

    vm.stopPrank();
  }

  function test_redeem_BranchAvailableLiquidityInsufficient() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.setAssetPair(address(_token), branchChainId2, branchAsset1);
    _assetManager.setHubAssetRedeemStatus(branchChainId1, address(_token), true);
    _assetManager.setHubAssetRedeemStatus(branchChainId2, address(_token), true);
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));
    _assetManager.deposit(branchChainId1, branchAsset1, user1, 100 ether);
    _assetManager.deposit(branchChainId2, branchAsset1, user1, 50 ether);
    vm.stopPrank();

    vm.startPrank(user1);

    vm.expectRevert(_errBranchAvailableLiquidityInsufficient(branchChainId1, address(_token), 100 ether, 101 ether));
    _assetManager.redeem(branchChainId1, address(_token), user1, 101 ether);

    vm.expectRevert(_errBranchAvailableLiquidityInsufficient(branchChainId2, address(_token), 50 ether, 51 ether));
    _assetManager.redeem(branchChainId2, address(_token), user1, 51 ether);

    assertEq(_assetManager.collateral(branchChainId1, address(_token)), 100 ether);
    _assetManager.redeem(branchChainId1, address(_token), user1, 100 ether);
    assertEq(_assetManager.collateral(branchChainId1, address(_token)), 0 ether);

    assertEq(_assetManager.collateral(branchChainId2, address(_token)), 50 ether);
    _assetManager.redeem(branchChainId2, address(_token), user1, 40 ether);
    assertEq(_assetManager.collateral(branchChainId2, address(_token)), 10 ether);

    vm.stopPrank();
  }

  function test_allocateMatrix() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    _assetManager.setStrategist(address(_matrixVault), strategist);

    _assetManagerEntrypoint.deposit(branchChainId1, branchAsset1, user1, 100 ether); // mint 100 of _token to user1
    vm.stopPrank();

    vm.startPrank(user1);

    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.prank(strategist);
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 100 ether);

    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 100 ether);
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 0);
  }

  function test_allocateMatrix_Unauthorized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    _assetManager.setStrategist(address(_matrixVault), strategist);

    _assetManagerEntrypoint.deposit(branchChainId1, branchAsset1, user1, 100 ether); // mint 100 of _token to user1
    vm.stopPrank();

    vm.startPrank(user1);

    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 100 ether);
  }

  function test_allocateMatrix_MatrixNotInitialized() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    // _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    _assetManager.setStrategist(address(_matrixVault), strategist);

    _assetManagerEntrypoint.deposit(branchChainId1, branchAsset1, user1, 100 ether); // mint 100 of _token to user1
    vm.stopPrank();

    vm.startPrank(user1);

    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.startPrank(strategist);

    vm.expectRevert(_errMatrixNotInitialized(branchChainId1, address(_matrixVault)));
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 100 ether);

    vm.stopPrank();
  }

  function test_allocateMatrix_MatrixInsufficient() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    _assetManager.setStrategist(address(_matrixVault), strategist);

    _assetManagerEntrypoint.deposit(branchChainId1, branchAsset1, user1, 100 ether); // mint 100 of _token to user1
    vm.stopPrank();

    vm.startPrank(user1);

    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);

    vm.stopPrank();

    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.startPrank(strategist);

    vm.expectRevert(_errMatrixInsufficient(address(_matrixVault)));
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 101 ether);

    vm.stopPrank();
  }

  function test_allocateMatrix_BranchAvailableLiquidityInsufficient() public {
    vm.startPrank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
    _assetManager.setAssetPair(address(_token), branchChainId2, branchAsset2);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    _assetManager.initializeMatrix(branchChainId2, address(_matrixVault));
    _assetManager.setStrategist(address(_matrixVault), strategist);

    _assetManagerEntrypoint.deposit(branchChainId1, branchAsset1, user1, 100 ether); // mint 100 of _token to user1
    _assetManagerEntrypoint.deposit(branchChainId2, branchAsset2, user1, 100 ether); // mint 100 of _token to user1
    vm.stopPrank();

    vm.startPrank(user1);
    _token.approve(address(_matrixVault), 200 ether);
    _matrixVault.deposit(200 ether, user1);
    vm.stopPrank();

    vm.startPrank(strategist);

    assertEq(_assetManager.branchAvailableLiquidity(branchChainId1, address(_token)), 100 ether);
    assertEq(_assetManager.branchAvailableLiquidity(branchChainId2, address(_token)), 100 ether);
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 200 ether);
    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 0 ether);

    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 30 ether);
    _assetManager.allocateMatrix(branchChainId2, address(_matrixVault), 50 ether);

    assertEq(_assetManager.branchAvailableLiquidity(branchChainId1, address(_token)), 70 ether);
    assertEq(_assetManager.branchAvailableLiquidity(branchChainId2, address(_token)), 50 ether);
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 120 ether);
    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 80 ether);

    vm.expectRevert(_errBranchAvailableLiquidityInsufficient(branchChainId1, address(_token), 70 ether, 71 ether));
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 71 ether);

    vm.stopPrank();
  }

  function test_deallocateMatrix() public {
    test_allocateMatrix();
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 0);
    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 100 ether);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.deallocateMatrix(branchChainId1, address(_matrixVault), 100 ether);

    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);
    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 0);
  }

  function test_deallocateMatrix_Unauthorized() public {
    test_allocateMatrix();
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 0);
    assertEq(_assetManager.matrixAlloc(address(_matrixVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.deallocateMatrix(branchChainId1, address(_matrixVault), 100 ether);
  }

  function test_reserveMatrix() public {
    test_deallocateMatrix();
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.prank(owner);
    _reclaimQueue.enable(address(_matrixVault));

    vm.prank(user1); // Resolve
    _matrixVault.transfer(address(_reclaimQueue), 10 ether);

    vm.prank(strategist);
    _assetManager.reserveMatrix(address(_matrixVault), 10 ether);

    assertEq(_matrixVault.balanceOf(address(_reclaimQueue)), 0);
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 90 ether);
  }

  function test_reserveMatrix_Unauthorized() public {
    test_deallocateMatrix();
    assertEq(_assetManager.matrixIdle(address(_matrixVault)), 100 ether);

    vm.prank(owner);
    _reclaimQueue.enable(address(_matrixVault));

    vm.prank(user1); // Resolve
    _matrixVault.transfer(address(_reclaimQueue), 10 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.reserveMatrix(address(_matrixVault), 10 ether);
  }

  function test_settleMatrixYield() public {
    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleMatrixYield(branchChainId1, address(_matrixVault), 100 ether);

    assertEq(_token.balanceOf(address(_assetManager)), 0);
  }

  function test_settleMatrixYield_Unauthorized() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleMatrixYield(branchChainId1, address(_matrixVault), 100 ether);
  }

  function test_settleMatrixLoss() public {
    test_deposit();
    assertEq(_token.balanceOf(user1), 100 ether);

    vm.startPrank(user1);
    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);
    vm.stopPrank();

    vm.startPrank(owner);
    _assetManager.setStrategist(address(_matrixVault), strategist);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
    vm.stopPrank();

    vm.prank(strategist);
    _assetManager.allocateMatrix(branchChainId1, address(_matrixVault), 100 ether);

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_matrixVault)), 100 ether);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleMatrixLoss(branchChainId1, address(_matrixVault), 10 ether);

    assertEq(_token.balanceOf(address(_matrixVault)), 100 ether - 10 ether);
  }

  function test_settleMatrixLoss_Unauthorized() public {
    test_deposit();
    assertEq(_token.balanceOf(user1), 100 ether);

    vm.startPrank(user1);
    _token.approve(address(_matrixVault), 100 ether);
    _matrixVault.deposit(100 ether, user1);
    vm.stopPrank();

    assertEq(_token.balanceOf(user1), 0);
    assertEq(_token.balanceOf(address(_matrixVault)), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleMatrixLoss(branchChainId1, address(_matrixVault), 10 ether);
  }

  function test_settleMatrixExtraRewards() public {
    MockERC20Snapshots rewardToken = new MockERC20Snapshots();
    rewardToken.initialize('Reward', '$REWARD');

    vm.startPrank(owner);
    _assetManager.setTreasury(address(_treasury));
    _assetManager.setAssetPair(address(rewardToken), branchChainId1, branchRewardTokenAddress);
    vm.stopPrank();

    assertEq(rewardToken.totalSupply(), 0);

    vm.prank(address(_assetManagerEntrypoint));
    _assetManager.settleMatrixExtraRewards(branchChainId1, address(_matrixVault), branchRewardTokenAddress, 100 ether);

    assertEq(rewardToken.totalSupply(), 100 ether);
  }

  function test_settleMatrixExtraRewards_Unauthorized() public {
    MockERC20Snapshots rewardToken = new MockERC20Snapshots();
    rewardToken.initialize('Reward', '$REWARD');

    vm.startPrank(owner);
    _assetManager.setTreasury(address(_treasury));
    _assetManager.setAssetPair(address(rewardToken), branchChainId1, branchRewardTokenAddress);
    vm.stopPrank();

    vm.expectRevert(StdError.Unauthorized.selector);
    _assetManager.settleMatrixExtraRewards(branchChainId1, address(_matrixVault), branchRewardTokenAddress, 100 ether);
  }

  function test_settleMatrixExtraRewards_BranchAssetPairNotExist() public {
    vm.startPrank(owner);
    _assetManager.setTreasury(address(_treasury));
    // _assetManager.setAssetPair(address(rewardToken), branchChainId1, branchRewardTokenAddress);
    vm.stopPrank();

    vm.startPrank(address(_assetManagerEntrypoint));

    vm.expectRevert(_errBranchAssetPairNotExist(branchRewardTokenAddress));
    _assetManager.settleMatrixExtraRewards(branchChainId1, address(_matrixVault), branchRewardTokenAddress, 100 ether);

    vm.stopPrank();
  }

  function test_initializeAsset() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(owner);
    _assetManager.initializeAsset(branchChainId1, address(_token));

    assertEq(_assetManager.branchAsset(address(_token), branchChainId1), branchAsset1);
  }

  function test_initializeAsset_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.initializeAsset(branchChainId1, address(_token));
  }

  function test_initializeAsset_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('hubAsset'));
    _assetManager.initializeAsset(branchChainId1, address(0));

    vm.stopPrank();
  }

  function test_initializeAsset_BranchAssetPairNotExist() public {
    vm.startPrank(owner);

    vm.expectRevert(_errBranchAssetPairNotExist(address(0)));
    _assetManager.initializeAsset(branchChainId1, address(_token));

    vm.stopPrank();
  }

  function test_initializeMatrix() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.prank(owner);
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));

    assertTrue(_assetManager.matrixInitialized(branchChainId1, address(_matrixVault)));
  }

  function test_initializeMatrix_Unauthorized() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));
  }

  function test_initializeMatrix_InvalidParameter() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('matrixVault'));
    _assetManager.initializeMatrix(branchChainId1, address(0));

    vm.stopPrank();
  }

  function test_initializeMatrix_BranchAssetPairNotExist() public {
    vm.startPrank(owner);

    vm.expectRevert(_errBranchAssetPairNotExist(address(0)));
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));

    vm.stopPrank();
  }

  function test_initializeMatrix_MatrixAlreadyInitialized() public {
    test_initializeMatrix();
    assertTrue(_assetManager.matrixInitialized(branchChainId1, address(_matrixVault)));

    vm.startPrank(owner);

    vm.expectRevert(_errMatrixAlreadyInitialized(branchChainId1, address(_matrixVault)));
    _assetManager.initializeMatrix(branchChainId1, address(_matrixVault));

    vm.stopPrank();
  }

  function test_setAssetPair() public {
    vm.prank(owner);
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);

    assertEq(_assetManager.branchAsset(address(_token), branchChainId1), branchAsset1);
  }

  function test_setAssetPair_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setAssetPair(address(_token), branchChainId1, branchAsset1);
  }

  function test_setAssetPair_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('hubAsset'));
    _assetManager.setAssetPair(address(0), branchChainId1, branchAsset1);

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

  function test_setReclaimQueue() public {
    ReclaimQueue reclaimQueueImpl = new ReclaimQueue();
    ReclaimQueue newReclaimQueue = ReclaimQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(reclaimQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(ReclaimQueue.initialize, (owner, address(_assetManager)))
          )
        )
      )
    );

    assertEq(_assetManager.reclaimQueue(), address(_reclaimQueue));

    vm.prank(owner);
    _assetManager.setReclaimQueue(address(newReclaimQueue));
    assertEq(_assetManager.reclaimQueue(), address(newReclaimQueue));
  }

  function test_setReclaimQueue_Unauthorized() public {
    ReclaimQueue reclaimQueueImpl = new ReclaimQueue();
    ReclaimQueue newReclaimQueue = ReclaimQueue(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(reclaimQueueImpl),
            address(_proxyAdmin),
            abi.encodeCall(ReclaimQueue.initialize, (owner, address(_assetManager)))
          )
        )
      )
    );

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setReclaimQueue(address(newReclaimQueue));
  }

  function test_setReclaimQueue_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('ReclaimQueue'));
    _assetManager.setReclaimQueue(address(0));

    vm.stopPrank();
  }

  function test_setTreasury() public {
    assertEq(_assetManager.treasury(), address(_treasury));

    Treasury newTreasury = new Treasury();

    vm.prank(owner);
    _assetManager.setTreasury(address(newTreasury));

    assertEq(_assetManager.treasury(), address(newTreasury));
  }

  function test_setTreasury_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setTreasury(address(_treasury));
  }

  function test_setTreasury_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('Treasury'));
    _assetManager.setTreasury(address(0));

    vm.stopPrank();
  }

  function test_setStrategist() public {
    assertEq(_assetManager.strategist(address(_matrixVault)), address(0));

    vm.prank(owner);
    _assetManager.setStrategist(address(_matrixVault), strategist);

    assertEq(_assetManager.strategist(address(_matrixVault)), strategist);

    address newStrategist = makeAddr('newStrategist');

    vm.prank(owner);
    _assetManager.setStrategist(address(_matrixVault), newStrategist);

    assertEq(_assetManager.strategist(address(_matrixVault)), newStrategist);
  }

  function test_setStrategist_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _assetManager.setStrategist(address(_matrixVault), strategist);
  }

  function test_setStrategist_InvalidParameter() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('MatrixVault'));
    _assetManager.setStrategist(address(0), strategist);

    vm.stopPrank();
  }

  function _errTreasuryNotSet() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManagerStorageV1.IAssetManagerStorageV1__TreasuryNotSet.selector);
  }

  function _errBranchAssetPairNotExist(address branchAsset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__BranchAssetPairNotExist.selector, branchAsset
    );
  }

  function _errMatrixNotInitialized(uint256 chainId, address matrixVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__MatrixNotInitialized.selector, chainId, matrixVault
    );
  }

  function _errMatrixAlreadyInitialized(uint256 chainId, address matrixVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__MatrixAlreadyInitialized.selector, chainId, matrixVault
    );
  }

  function _errBranchAvailableLiquidityInsufficient(
    uint256 chainId,
    address hubAsset,
    uint256 available,
    uint256 amount
  ) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IAssetManagerStorageV1.IAssetManagerStorageV1__BranchAvailableLiquidityInsufficient.selector,
      chainId,
      hubAsset,
      available,
      amount
    );
  }

  function _errInvalidMatrixVault(address matrixVault, address hubAsset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManager.IAssetManager__InvalidMatrixVault.selector, matrixVault, hubAsset);
  }

  function _errMatrixInsufficient(address matrixVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IAssetManager.IAssetManager__MatrixInsufficient.selector, matrixVault);
  }
}
