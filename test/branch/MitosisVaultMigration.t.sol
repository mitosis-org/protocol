// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { IERC20 } from '@oz/interfaces/IERC20.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { MitosisVault } from '../../src/branch/MitosisVault.sol';
import { MitosisVaultMigration } from '../../src/branch/MitosisVaultMigration.sol';
import { VLFStrategyExecutor } from '../../src/branch/strategy/VLFStrategyExecutor.sol';
import { IMitosisVault, AssetAction } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultVLF, VLFAction } from '../../src/interfaces/branch/IMitosisVaultVLF.sol';
import { StdError } from '../../src/lib/StdError.sol';
import { MockERC20Snapshots } from '../mock/MockERC20Snapshots.t.sol';
import { MockMitosisVaultEntrypoint } from '../mock/MockMitosisVaultEntrypoint.t.sol';
import { MockVLFStrategyExecutorMigration } from '../mock/MockVLFStrategyExecutorMigration.t.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract MitosisVaultMigrationTest is Toolkit {
  MitosisVaultMigration internal _mitosisVaultMigration;
  MockMitosisVaultEntrypoint internal _mitosisVaultEntrypoint;
  MockERC20Snapshots internal _token;
  MockVLFStrategyExecutorMigration internal _vlfStrategyExecutorMigration;

  address immutable owner = makeAddr('owner');
  address immutable liquidityManager = makeAddr('liquidityManager');
  address immutable migrator = makeAddr('migrator');
  address immutable hubVLFVault = makeAddr('hubVLFVault');
  address immutable depositAndSupplyTo = makeAddr('depositAndSupplyTo');

  function setUp() public {
    _mitosisVaultMigration = MitosisVaultMigration(
      payable(new ERC1967Proxy(address(new MitosisVaultMigration()), abi.encodeCall(MitosisVault.initialize, (owner))))
    );

    _mitosisVaultEntrypoint = new MockMitosisVaultEntrypoint();

    _token = new MockERC20Snapshots();
    _token.initialize('Token', 'TKN');

    _vlfStrategyExecutorMigration = MockVLFStrategyExecutorMigration(
      payable(
        new ERC1967Proxy(
          address(new MockVLFStrategyExecutorMigration()),
          abi.encodeCall(
            VLFStrategyExecutor.initialize, (IMitosisVault(address(_mitosisVaultMigration)), _token, hubVLFVault, owner)
          )
        )
      )
    );

    vm.startPrank(owner);
    _mitosisVaultMigration.grantRole(_mitosisVaultMigration.LIQUIDITY_MANAGER_ROLE(), liquidityManager);
    _mitosisVaultMigration.grantRole(_mitosisVaultMigration.MIGRATOR_ROLE(), migrator);
    _mitosisVaultMigration.setEntrypoint(address(_mitosisVaultEntrypoint));
    vm.stopPrank();
  }

  function _setupVLF() internal {
    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVaultMigration.initializeAsset(address(_token));
    _mitosisVaultMigration.initializeVLF(hubVLFVault, address(_token));
    vm.stopPrank();

    vm.prank(owner);
    _mitosisVaultMigration.setVLFStrategyExecutor(hubVLFVault, address(_vlfStrategyExecutorMigration));
  }

  function test_initiateMigration() public {
    _setupVLF();

    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    assertEq(_mitosisVaultMigration.unresolvedDepositAmount(hubVLFVault), settleAmount);
    assertEq(_mitosisVaultMigration.unresolvedFetchAmount(hubVLFVault), settleAmount);
  }

  function test_initiateMigration_Unauthorized() public {
    _setupVLF();

    vm.expectRevert(_errAccessControlUnauthorized(owner, _mitosisVaultMigration.MIGRATOR_ROLE()));
    vm.prank(owner);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);
  }

  function test_initiateMigration_VLFNotInitialized() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVaultMigration.initializeAsset(address(_token));
    vm.stopPrank();

    vm.expectRevert(_errVLFNotInitialized(hubVLFVault));
    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);
  }

  function test_initiateMigration_InvalidStrategyExecutor() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVaultMigration.initializeAsset(address(_token));
    _mitosisVaultMigration.initializeVLF(hubVLFVault, address(_token));
    vm.stopPrank();

    // Don't set strategy executor

    vm.expectRevert(_errInvalidParameter('strategyExecutor'));
    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);
  }

  function test_migrateVLFAssets() public {
    _setupVLF();

    // Setup initial migration
    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    // Setup parameters for migration
    uint256 depositAndSupplyAmount = 60 ether;
    uint256 donationAmount = 40 ether;
    uint256 depositAndSupplyGasFee = 1 ether;
    uint256 donationGasFee = 1 ether;

    vm.prank(owner);
    _mitosisVaultMigration.resumeAsset(address(_token), AssetAction.Deposit);

    // Set cap for the token to allow deposits
    vm.prank(liquidityManager);
    _mitosisVaultMigration.setCap(address(_token), type(uint256).max);

    // Set gas fees for entrypoint
    _mitosisVaultEntrypoint.setGas(_mitosisVaultEntrypoint.depositWithSupplyVLF.selector, depositAndSupplyGasFee);
    _mitosisVaultEntrypoint.setGas(_mitosisVaultEntrypoint.deposit.selector, donationGasFee);

    vm.deal(migrator, 10 ether);
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: depositAndSupplyGasFee + donationGasFee }(
      address(_token),
      hubVLFVault,
      depositAndSupplyTo,
      depositAndSupplyAmount,
      donationAmount,
      depositAndSupplyGasFee,
      donationGasFee
    );

    assertEq(_mitosisVaultMigration.unresolvedDepositAmount(hubVLFVault), 0);
  }

  function test_migrateVLFAssets_Unauthorized() public {
    _setupVLF();

    vm.expectRevert(_errAccessControlUnauthorized(owner, _mitosisVaultMigration.MIGRATOR_ROLE()));
    vm.prank(owner);
    _mitosisVaultMigration.migrateVLFAssets(
      address(_token), hubVLFVault, depositAndSupplyTo, 60 ether, 40 ether, 1 ether, 1 ether
    );
  }

  function test_migrateVLFAssets_InvalidAmounts() public {
    _setupVLF();

    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    vm.deal(migrator, 10 ether);
    vm.expectRevert(_errInvalidParameter('depositAndSupplyAmount + donationAmount'));
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: 2 ether }(
      address(_token),
      hubVLFVault,
      depositAndSupplyTo,
      50 ether, // Wrong amount - should be 60 ether
      40 ether,
      1 ether,
      1 ether
    );
  }

  function test_migrateVLFAssets_ZeroDepositAndSupplyTo() public {
    _setupVLF();

    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    vm.deal(migrator, 10 ether);
    vm.expectRevert(abi.encodeWithSelector(StdError.ZeroAddress.selector, 'depositAndSupplyTo'));
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: 2 ether }(
      address(_token),
      hubVLFVault,
      address(0), // Zero address
      60 ether,
      40 ether,
      1 ether,
      1 ether
    );
  }

  function test_migrateVLFAssets_ZeroDepositAndSupplyAmount() public {
    _setupVLF();

    uint256 settleAmount = 40 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    vm.deal(migrator, 10 ether);
    vm.expectRevert(_errZeroAmount());
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: 2 ether }(
      address(_token),
      hubVLFVault,
      depositAndSupplyTo,
      0, // Zero amount
      40 ether,
      1 ether,
      1 ether
    );
  }

  function test_migrateVLFAssets_ZeroDonationAmount() public {
    _setupVLF();

    uint256 settleAmount = 60 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    vm.deal(migrator, 10 ether);
    vm.expectRevert(_errZeroAmount());
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: 2 ether }(
      address(_token),
      hubVLFVault,
      depositAndSupplyTo,
      60 ether,
      0, // Zero amount
      1 ether,
      1 ether
    );
  }

  function test_migrateVLFAssets_InvalidMsgValue() public {
    _setupVLF();

    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    vm.deal(migrator, 10 ether);
    vm.expectRevert(_errInvalidParameter('msg.value'));
    vm.prank(migrator);
    _mitosisVaultMigration.migrateVLFAssets{ value: 1 ether }( // Wrong value
    address(_token), hubVLFVault, depositAndSupplyTo, 60 ether, 40 ether, 1 ether, 1 ether);
  }

  function test_manualFetchVLF() public {
    _setupVLF();

    uint256 settleAmount = 100 ether;
    _vlfStrategyExecutorMigration.setMockSettleReturn(settleAmount);

    vm.prank(migrator);
    _mitosisVaultMigration.initiateMigration(hubVLFVault);

    // Allocate some VLF to have available liquidity
    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVaultMigration.allocateVLF(hubVLFVault, 200 ether);

    vm.prank(migrator);
    _mitosisVaultMigration.manualFetchVLF(hubVLFVault);

    assertEq(_mitosisVaultMigration.unresolvedFetchAmount(hubVLFVault), 0);
    assertEq(_mitosisVaultMigration.availableVLF(hubVLFVault), 100 ether); // 200 - 100
  }

  function test_manualFetchVLF_Unauthorized() public {
    _setupVLF();

    vm.expectRevert(_errAccessControlUnauthorized(owner, _mitosisVaultMigration.MIGRATOR_ROLE()));
    vm.prank(owner);
    _mitosisVaultMigration.manualFetchVLF(hubVLFVault);
  }

  function test_manualFetchVLF_InvalidAmount() public {
    _setupVLF();

    vm.expectRevert(_errInvalidParameter('amount'));
    vm.prank(migrator);
    _mitosisVaultMigration.manualFetchVLF(hubVLFVault);
  }

  function test_manualFetchVLF_VLFNotInitialized() public {
    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVaultMigration.initializeAsset(address(_token));
    vm.stopPrank();

    vm.expectRevert(_errInvalidParameter('amount'));
    vm.prank(migrator);
    _mitosisVaultMigration.manualFetchVLF(hubVLFVault);
  }

  function test_unresolvedDepositAmount() public view {
    assertEq(_mitosisVaultMigration.unresolvedDepositAmount(hubVLFVault), 0);
  }

  function test_unresolvedFetchAmount() public view {
    assertEq(_mitosisVaultMigration.unresolvedFetchAmount(hubVLFVault), 0);
  }

  // Helper functions for error messages
  function _errVLFNotInitialized(address _hubVLFVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IMitosisVaultVLF.IMitosisVaultVLF__VLFNotInitialized.selector, _hubVLFVault);
  }
}
