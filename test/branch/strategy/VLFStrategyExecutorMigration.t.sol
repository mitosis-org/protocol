// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { IERC20 } from '@oz/interfaces/IERC20.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { MitosisVault } from '../../../src/branch/MitosisVault.sol';
import { VLFStrategyExecutor } from '../../../src/branch/strategy/VLFStrategyExecutor.sol';
import { VLFStrategyExecutorMigration } from '../../../src/branch/strategy/VLFStrategyExecutorMigration.sol';
import { IMitosisVault } from '../../../src/interfaces/branch/IMitosisVault.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockERC20Snapshots } from '../../mock/MockERC20Snapshots.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockTally {
  function pendingDepositBalance(bytes memory) external pure returns (uint256) {
    return 0;
  }

  function totalBalance(bytes memory) external pure returns (uint256) {
    return 0;
  }

  function pendingWithdrawBalance(bytes memory) external pure returns (uint256) {
    return 0;
  }
}

contract VLFStrategyExecutorMigrationTest is Toolkit {
  VLFStrategyExecutorMigration internal _executor;
  MockERC20Snapshots internal _token;
  MitosisVault internal _vault;

  address immutable owner = makeAddr('owner');
  address immutable hubVLFVault = makeAddr('hubVLFVault');
  address immutable unauthorizedUser = makeAddr('unauthorizedUser');

  function setUp() public {
    _vault = MitosisVault(
      payable(new ERC1967Proxy(address(new MitosisVault()), abi.encodeCall(MitosisVault.initialize, (owner))))
    );

    _token = new MockERC20Snapshots();
    _token.initialize('Token', 'TKN');

    _executor = VLFStrategyExecutorMigration(
      payable(
        new ERC1967Proxy(
          address(new VLFStrategyExecutorMigration()),
          abi.encodeCall(VLFStrategyExecutor.initialize, (IMitosisVault(address(_vault)), _token, hubVLFVault, owner))
        )
      )
    );

    // Set up mock tally to avoid reverts in _totalBalance
    address mockTally = address(new MockTally());
    vm.prank(owner);
    _executor.setTally(mockTally);
  }

  function test_manualSettle_Success() public {
    // Give executor some tokens to simulate balance
    _token.mint(address(_executor), 150 ether);

    vm.prank(address(_vault));
    uint256 diff = _executor.manualSettle();

    // The diff should be the difference between current total and stored total
    // Since this is a fresh deployment, storedTotalBalance starts at 0
    assertEq(diff, 150 ether);
    assertEq(_executor.storedTotalBalance(), 150 ether);
  }

  function test_manualSettle_Unauthorized() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    vm.prank(unauthorizedUser);
    _executor.manualSettle();
  }

  function test_manualSettle_OnlyVaultCanCall() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    vm.prank(owner);
    _executor.manualSettle();
  }

  function test_manualSettle_TotalBalanceLessThanStored() public {
    // Give executor some tokens first
    _token.mint(address(_executor), 100 ether);

    // Set stored balance by calling manualSettle first
    vm.prank(address(_vault));
    _executor.manualSettle();

    // Now remove some tokens to simulate loss
    vm.prank(address(_executor));
    _token.transfer(address(1), 50 ether);

    // This should fail because totalBalance < storedTotalBalance
    vm.expectRevert('totalBalance < storedTotalBalance');
    vm.prank(address(_vault));
    _executor.manualSettle();
  }

  function test_manualSettle_NoChange() public {
    // Give executor some tokens
    _token.mint(address(_executor), 100 ether);

    // First call to set stored balance
    vm.prank(address(_vault));
    uint256 diff1 = _executor.manualSettle();
    assertEq(diff1, 100 ether);

    // Second call with no balance change should return 0
    vm.prank(address(_vault));
    uint256 diff2 = _executor.manualSettle();
    assertEq(diff2, 0);
  }

  function test_manualSettle_PositiveYield() public {
    // Give executor initial tokens
    _token.mint(address(_executor), 100 ether);

    // First call to set stored balance
    vm.prank(address(_vault));
    uint256 diff1 = _executor.manualSettle();
    assertEq(diff1, 100 ether);

    // Add more tokens to simulate yield
    _token.mint(address(_executor), 50 ether);

    // Second call should return the yield
    vm.prank(address(_vault));
    uint256 diff2 = _executor.manualSettle();
    assertEq(diff2, 50 ether);
    assertEq(_executor.storedTotalBalance(), 150 ether);
  }

  function test_totalBalance() public {
    _token.mint(address(_executor), 100 ether);
    assertEq(_executor.totalBalance(), 100 ether);
  }

  function test_storedTotalBalance() public {
    assertEq(_executor.storedTotalBalance(), 0);

    _token.mint(address(_executor), 100 ether);

    vm.prank(address(_vault));
    _executor.manualSettle();

    assertEq(_executor.storedTotalBalance(), 100 ether);
  }

  function test_vault() public view {
    assertEq(address(_executor.vault()), address(_vault));
  }

  function test_asset() public view {
    assertEq(address(_executor.asset()), address(_token));
  }

  function test_hubVLFVault() public view {
    assertEq(_executor.hubVLFVault(), hubVLFVault);
  }
}
