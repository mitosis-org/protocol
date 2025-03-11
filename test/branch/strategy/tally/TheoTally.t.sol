// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';

import { ITheoDepositVault } from '../../../../src/branch/strategy/tally/external/ITheoDepositVault.sol';
import { TheoTally } from '../../../../src/branch/strategy/tally/TheoTally.sol';
import { MockContract } from '../../../util/MockContract.sol';
import { Toolkit } from '../../../util/Toolkit.sol';

contract TheoTallyTest is Toolkit {
  MockContract _theoDepositVault;
  TheoTally _theoTally;

  address _user = makeAddr('user');

  function setUp() public {
    _theoDepositVault = new MockContract();
    _theoTally = new TheoTally(ITheoDepositVault(address(_theoDepositVault)));

    _theoDepositVault.setRet(ITheoDepositVault.decimals.selector, '', false, abi.encode(18));
  }

  function test_totalBalance() public {
    _theoDepositVault.setRet(ITheoDepositVault.round.selector, '', false, abi.encode(10));
    _theoDepositVault.setRet(
      ITheoDepositVault.shareBalances.selector, abi.encode(_user), false, abi.encode(80 ether, 20 ether)
    );
    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1 ether));

    vm.prank(_user);
    uint256 totalBalance = _theoTally.totalBalance('');

    assertEq(totalBalance, 100 ether);
  }

  function test_totalBalance_per_price() public {
    _theoDepositVault.setRet(ITheoDepositVault.round.selector, '', false, abi.encode(10));
    _theoDepositVault.setRet(
      ITheoDepositVault.shareBalances.selector, abi.encode(_user), false, abi.encode(80 ether, 20 ether)
    );

    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1 ether));

    vm.prank(_user);
    assertEq(_theoTally.totalBalance(''), 100 ether);

    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1.5 ether));

    vm.prank(_user);
    assertEq(_theoTally.totalBalance(''), 150 ether);

    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(0.5 ether));

    vm.prank(_user);
    assertEq(_theoTally.totalBalance(''), 50 ether);
  }

  function test_withdrawableBalance() public {
    _theoDepositVault.setRet(ITheoDepositVault.round.selector, '', false, abi.encode(10));
    _theoDepositVault.setRet(
      ITheoDepositVault.shareBalances.selector, abi.encode(_user), false, abi.encode(80 ether, 20 ether)
    );
    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1 ether));

    vm.prank(_user);
    assertEq(_theoTally.withdrawableBalance(''), 20 ether);

    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1.5 ether));

    vm.prank(_user);
    assertEq(_theoTally.withdrawableBalance(''), 30 ether);

    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(0.5 ether));

    vm.prank(_user);
    assertEq(_theoTally.withdrawableBalance(''), 10 ether);
  }

  function test_pendingWithdrawBalance() public {
    _theoDepositVault.setRet(ITheoDepositVault.round.selector, '', false, abi.encode(10));
    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1 ether));

    _theoDepositVault.setRet(
      ITheoDepositVault.withdrawals.selector,
      abi.encode(_user),
      false,
      abi.encode(ITheoDepositVault.Withdrawal({ round: 10, shares: 100 ether }))
    );

    vm.prank(_user);
    assertEq(_theoTally.pendingWithdrawBalance(''), 100 ether);
  }

  function test_pendingWithdrawBalance_past_round() public {
    _theoDepositVault.setRet(ITheoDepositVault.round.selector, '', false, abi.encode(10));

    // round 10: 1 ether (current)
    // round 9: 0.5 ether
    // round 8 : 0.1 ether
    _theoDepositVault.setRet(ITheoDepositVault.pricePerShare.selector, '', false, abi.encode(1 ether));
    _theoDepositVault.setRet(ITheoDepositVault.roundPricePerShare.selector, abi.encode(9), false, abi.encode(0.5 ether));
    _theoDepositVault.setRet(ITheoDepositVault.roundPricePerShare.selector, abi.encode(8), false, abi.encode(0.1 ether));

    _theoDepositVault.setRet(
      ITheoDepositVault.withdrawals.selector,
      abi.encode(_user),
      false,
      abi.encode(ITheoDepositVault.Withdrawal({ round: 9, shares: 100 ether }))
    );

    vm.prank(_user);
    assertEq(_theoTally.pendingWithdrawBalance(''), 50 ether);

    _theoDepositVault.setRet(
      ITheoDepositVault.withdrawals.selector,
      abi.encode(_user),
      false,
      abi.encode(ITheoDepositVault.Withdrawal({ round: 8, shares: 100 ether }))
    );

    vm.prank(_user);
    assertEq(_theoTally.pendingWithdrawBalance(''), 10 ether);

    // round 10: 1 ether (current)
    // round 9: 1.5 ether
    // round 8 : 2 ether
    _theoDepositVault.setRet(ITheoDepositVault.roundPricePerShare.selector, abi.encode(9), false, abi.encode(1.5 ether));
    _theoDepositVault.setRet(ITheoDepositVault.roundPricePerShare.selector, abi.encode(8), false, abi.encode(2 ether));

    _theoDepositVault.setRet(
      ITheoDepositVault.withdrawals.selector,
      abi.encode(_user),
      false,
      abi.encode(ITheoDepositVault.Withdrawal({ round: 9, shares: 100 ether }))
    );

    vm.prank(_user);
    assertEq(_theoTally.pendingWithdrawBalance(''), 150 ether);

    _theoDepositVault.setRet(
      ITheoDepositVault.withdrawals.selector,
      abi.encode(_user),
      false,
      abi.encode(ITheoDepositVault.Withdrawal({ round: 8, shares: 100 ether }))
    );

    vm.prank(_user);
    assertEq(_theoTally.pendingWithdrawBalance(''), 200 ether);
  }

  function test_protocolAddress() public {
    assertEq(_theoTally.protocolAddress(), address(_theoDepositVault));
  }

  function test_previewDeposit() public {
    assertEq(_theoTally.previewDeposit(100 ether, ''), 100 ether);
  }

  function test_previewWithdraw() public {
    assertEq(_theoTally.previewWithdraw(100 ether, ''), 0);
  }

  function test_pendingDepositBalance() public {
    assertEq(_theoTally.pendingDepositBalance(''), 0);
  }
}
