// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { ERC4626 } from '@solady/tokens/ERC4626.sol';
import { WETH } from '@solady/tokens/WETH.sol';

import { Ownable } from '@oz/access/Ownable.sol';
import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { BeaconProxy } from '@oz/proxy/beacon/BeaconProxy.sol';
import { IBeacon } from '@oz/proxy/beacon/IBeacon.sol';

import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { MatrixVaultCapped } from '../../../src/hub/matrix/MatrixVaultCapped.sol';
import { IAssetManager } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MatrixVaultTestBase is IBeacon, Toolkit {
  address owner = makeAddr('owner');
  address liquidityManager = makeAddr('liquidityManager');
  address user = makeAddr('user');
  address assetManager = _emptyContract();
  address reclaimQueue = _emptyContract();

  WETH weth;

  MatrixVaultBasic basicImpl;
  MatrixVaultCapped cappedImpl;
  address private defaultImpl;

  MatrixVaultBasic basic;
  MatrixVaultCapped capped;

  function setUp() public virtual {
    weth = new WETH();

    basicImpl = new MatrixVaultBasic();
    cappedImpl = new MatrixVaultCapped();

    vm.mockCall(
      address(assetManager),
      abi.encodeWithSelector(IAssetManagerStorageV1.reclaimQueue.selector),
      abi.encode(reclaimQueue)
    );

    vm.mockCall(address(assetManager), abi.encodeWithSelector(Ownable.owner.selector), abi.encode(owner));

    vm.mockCall(
      address(assetManager),
      abi.encodeWithSelector(IAssetManager.isLiquidityManager.selector, liquidityManager),
      abi.encode(true)
    );
    vm.mockCall(
      address(assetManager), abi.encodeWithSelector(IAssetManager.isLiquidityManager.selector, owner), abi.encode(false)
    );
    vm.mockCall(
      address(assetManager), abi.encodeWithSelector(IAssetManager.isLiquidityManager.selector, user), abi.encode(false)
    );

    defaultImpl = address(basicImpl);
    basic = MatrixVaultBasic(
      address(
        new BeaconProxy(
          address(this),
          abi.encodeCall(
            MatrixVaultBasic.initialize, //
            (assetManager, IERC20Metadata(address(weth)), 'B', 'B')
          )
        )
      )
    );

    defaultImpl = address(cappedImpl);
    capped = MatrixVaultCapped(
      address(
        new BeaconProxy(
          address(this),
          abi.encodeCall(
            MatrixVaultCapped.initialize, //
            (assetManager, IERC20Metadata(address(weth)), 'C', 'C')
          )
        )
      )
    );

    defaultImpl = address(0);
  }

  function implementation() public view override returns (address) {
    if (msg.sender == address(basic)) return address(basicImpl);
    if (msg.sender == address(capped)) return address(cappedImpl);
    if (defaultImpl != address(0)) return defaultImpl;
    revert('unauthorized');
  }
}

contract MatrixVaultBasicTest is MatrixVaultTestBase {
  function test_initialize() public view {
    assertEq(basic.asset(), address(weth));
    assertEq(basic.name(), 'B');
    assertEq(basic.symbol(), 'B');
    assertEq(basic.decimals(), 18 + 6);

    assertEq(basic.owner(), owner);
    assertEq(basic.assetManager(), assetManager);
    assertEq(basic.reclaimQueue(), reclaimQueue);

    assertEq(_erc1967Beacon(address(basic)), address(this));
  }

  function test_deposit(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(basic), amount);
    basic.deposit(amount, user);

    vm.stopPrank();

    assertEq(basic.balanceOf(user), amount * 1e6, 'balance');
    assertEq(basic.totalAssets(), amount, 'totalAssets');
    assertEq(basic.totalSupply(), amount * 1e6, 'totalSupply');
    assertEq(basic.convertToShares(amount), amount * 1e6, 'convertToShares');
    assertEq(basic.convertToAssets(amount * 1e6), amount, 'convertToAssets');
  }

  function test_mint(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(basic), amount);
    basic.mint(amount * 1e6, user);

    vm.stopPrank();

    assertEq(basic.balanceOf(user), amount * 1e6, 'balance');
    assertEq(basic.totalAssets(), amount, 'totalAssets');
    assertEq(basic.totalSupply(), amount * 1e6, 'totalSupply');
    assertEq(basic.convertToShares(amount), amount * 1e6, 'convertToShares');
    assertEq(basic.convertToAssets(amount * 1e6), amount, 'convertToAssets');
  }

  function test_withdraw(uint256 amount) public {
    test_deposit(amount);

    vm.prank(user);
    basic.approve(reclaimQueue, amount * 1e6);

    vm.prank(reclaimQueue);
    basic.withdraw(amount, user, user);

    assertEq(weth.balanceOf(user), amount, 'balance');
    assertEq(basic.balanceOf(user), 0, 'balance');
    assertEq(basic.totalAssets(), 0, 'totalAssets');
    assertEq(basic.totalSupply(), 0, 'totalSupply');
  }

  function test_withdraw_revertsIfUnauthorized(uint256 amount) public {
    test_deposit(amount);

    vm.prank(user);
    vm.expectRevert(StdError.Unauthorized.selector);
    basic.withdraw(amount, user, user);
  }

  function test_redeem(uint256 amount) public {
    test_deposit(amount);

    vm.prank(user);
    basic.approve(reclaimQueue, amount * 1e6);

    vm.prank(reclaimQueue);
    basic.redeem(amount * 1e6, user, user);

    assertEq(weth.balanceOf(user), amount, 'balance');
    assertEq(basic.balanceOf(user), 0, 'balance');
    assertEq(basic.totalAssets(), 0, 'totalAssets');
    assertEq(basic.totalSupply(), 0, 'totalSupply');
  }

  function test_redeem_revertsIfUnauthorized(uint256 amount) public {
    test_deposit(amount);

    vm.prank(user);
    vm.expectRevert(StdError.Unauthorized.selector);
    basic.redeem(amount * 1e6, user, user);
  }
}

contract MatrixVaultCappedTest is MatrixVaultTestBase {
  function setUp() public override {
    super.setUp();
  }

  function test_initialize() public view {
    assertEq(capped.asset(), address(weth));
    assertEq(capped.name(), 'C');
    assertEq(capped.symbol(), 'C');
    assertEq(capped.decimals(), 18 + 6);

    assertEq(capped.owner(), owner);
    assertEq(capped.assetManager(), assetManager);
    assertEq(capped.reclaimQueue(), reclaimQueue);

    assertEq(_erc1967Beacon(address(capped)), address(this));
  }

  function test_setCap(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);

    assertEq(capped.loadCap(), 0);

    vm.prank(liquidityManager);
    capped.setCap(amount);

    assertEq(capped.loadCap(), amount);
  }

  function test_setCap_revertsIfUnauthorized(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);

    vm.prank(owner);
    vm.expectRevert(StdError.Unauthorized.selector);
    capped.setCap(amount);
  }

  function test_deposit(uint256 cap, uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);
    vm.assume(amount <= cap && cap < type(uint64).max);

    vm.prank(liquidityManager);
    capped.setCap(cap * 1e6);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(capped), amount);
    capped.deposit(amount, user);

    vm.stopPrank();
  }

  function test_deposit_revertsIfCapExceeded(uint256 cap, uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);
    vm.assume(cap < amount);

    vm.prank(liquidityManager);
    capped.setCap(cap * 1e6);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(capped), amount);

    vm.expectRevert(ERC4626.DepositMoreThanMax.selector);
    capped.deposit(amount, user);

    vm.stopPrank();
  }

  function test_mint(uint256 cap, uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);
    vm.assume(amount <= cap && cap < type(uint64).max);

    vm.prank(liquidityManager);
    capped.setCap(cap * 1e6);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(capped), amount);
    capped.mint(amount * 1e6, user);

    vm.stopPrank();
  }

  function test_mint_revertsIfCapExceeded(uint256 cap, uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint64).max);
    vm.assume(amount > cap);

    vm.prank(liquidityManager);
    capped.setCap(cap * 1e6);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(capped), amount);

    vm.expectRevert(ERC4626.MintMoreThanMax.selector);
    capped.mint(amount * 1e6, user);

    vm.stopPrank();
  }

  function test_withdraw(uint256 cap, uint256 amount) public {
    test_deposit(cap, amount);

    vm.prank(user);
    capped.approve(reclaimQueue, amount * 1e6);

    vm.prank(reclaimQueue);
    capped.withdraw(amount, user, user);
  }

  function test_withdraw_revertsIfUnauthorized(uint256 cap, uint256 amount) public {
    test_deposit(cap, amount);

    vm.prank(user);
    vm.expectRevert(StdError.Unauthorized.selector);
    capped.withdraw(amount, user, user);
  }

  function test_redeem(uint256 cap, uint256 amount) public {
    test_deposit(cap, amount);

    vm.prank(user);
    capped.approve(reclaimQueue, amount * 1e6);

    vm.prank(reclaimQueue);
    capped.redeem(amount * 1e6, user, user);
  }

  function test_redeem_revertsIfUnauthorized(uint256 cap, uint256 amount) public {
    test_deposit(cap, amount);

    vm.prank(user);
    vm.expectRevert(StdError.Unauthorized.selector);
    capped.redeem(amount * 1e6, user, user);
  }
}
