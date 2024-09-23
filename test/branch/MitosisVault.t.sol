// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MitosisVault, AssetAction } from '../../src/branch/MitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { StdError } from '../../src/lib/StdError.sol';
import { MockERC20TWABSnapshots } from '../mock/MockERC20TWABSnapshots.t.sol';
import { MockMitosisVaultEntrypoint } from '../mock/MockMitosisVaultEntrypoint.t.sol';
import { MockStrategyExecutor } from '../mock/MockStrategyExecutor.t.sol';

contract MitosisVaultTest is Test {
  MitosisVault _mitosisVault;
  MockMitosisVaultEntrypoint _mitosisVaultEntrypoint;
  ProxyAdmin _proxyAdmin;
  MockERC20TWABSnapshots _token;
  MockStrategyExecutor _strategyExecutor;

  address immutable owner = makeAddr('owner');
  address immutable hubEOLVault = makeAddr('hubEOLVault');

  function setUp() public {
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
    _token.initialize('Token', 'TKN');

    _strategyExecutor = new MockStrategyExecutor(_mitosisVault, _token, hubEOLVault);

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
    _mitosisVault.setStrategyExecutor(hubEOLVault, address(_strategyExecutor));

    vm.prank(address(_strategyExecutor));
    _mitosisVault.deallocateEOL(hubEOLVault, 10 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 90 ether);

    vm.prank(address(_strategyExecutor));
    _mitosisVault.deallocateEOL(hubEOLVault, 90 ether);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), 0 ether);
  }

  function test_deallocateEOL_EOLNotInitialized() public { }
  function test_deallocateEOL_Unauthorized() public { }
  function test_deallocateEOL_balance______() public { }

  function _errAssetAlreadyInitialized(address asset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(MitosisVault.MitosisVault__AssetAlreadyInitialized.selector, asset);
  }

  function _errAssetNotInitialized(address asset) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(MitosisVault.MitosisVault__AssetNotInitialized.selector, asset);
  }

  function _errEOLAlreadyInitialized(address hubEOLVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(MitosisVault.MitosisVault__EOLAlreadyInitialized.selector, hubEOLVault);
  }

  function _errEOLNotInitiailized(address hubEOLVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(MitosisVault.MitosisVault__EOLNotInitialized.selector, hubEOLVault);
  }

  function _errZeroToAddress() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(StdError.ZeroAddress.selector, 'to');
  }
}
