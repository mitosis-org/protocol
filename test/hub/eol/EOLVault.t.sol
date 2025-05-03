// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Test } from '@std/Test.sol';

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';

import { EOLVault } from '../../../src/hub/eol/EOLVault.sol';

contract EOLVaultTest is Test {
  address owner = makeAddr('owner');
  address user = makeAddr('user');

  WETH weth;

  ERC1967Factory factory;
  EOLVault vault;

  function setUp() public {
    weth = new WETH();
    factory = new ERC1967Factory();

    vault = EOLVault(
      factory.deployAndCall(
        address(new EOLVault()), //
        owner,
        abi.encodeCall(EOLVault.initialize, (owner, IERC20Metadata(address(weth)), 'Mitosis EOL Wrapped ETH', 'miwETH'))
      )
    );
  }

  function test_init() public view {
    assertEq(vault.name(), 'Mitosis EOL Wrapped ETH');
    assertEq(vault.symbol(), 'miwETH');
    assertEq(vault.decimals(), 18 + 6);
    assertEq(vault.asset(), address(weth));
    assertEq(vault.owner(), owner);
  }

  function test_deposit(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint128).max);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(vault), amount);
    vault.deposit(amount, user);

    vm.stopPrank();

    assertEq(weth.balanceOf(address(vault)), amount);
    assertEq(vault.balanceOf(user), amount * 1e6);
    assertEq(vault.totalAssets(), amount);
    assertEq(vault.totalSupply(), amount * 1e6);
  }

  function test_mint(uint256 amount) public {
    vm.assume(0 < amount && amount < type(uint128).max);

    vm.deal(user, amount);
    vm.startPrank(user);

    weth.deposit{ value: amount }();
    weth.approve(address(vault), amount);
    vault.mint(amount * 1e6, user);

    vm.stopPrank();

    assertEq(weth.balanceOf(address(vault)), amount);
    assertEq(vault.balanceOf(user), amount * 1e6);
    assertEq(vault.totalAssets(), amount);
    assertEq(vault.totalSupply(), amount * 1e6);
  }

  function test_withdraw(uint256 amount) public {
    test_deposit(amount);

    vm.prank(user);
    vault.withdraw(amount, owner, user);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(vault.totalSupply(), 0);
    assertEq(weth.balanceOf(address(vault)), 0);
    assertEq(weth.balanceOf(owner), amount);
  }

  function test_redeem(uint256 amount) public {
    test_mint(amount);

    vm.prank(user);
    vault.redeem(amount * 1e6, owner, user);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(vault.totalSupply(), 0);
    assertEq(weth.balanceOf(address(vault)), 0);
    assertEq(weth.balanceOf(owner), amount);
  }
}
