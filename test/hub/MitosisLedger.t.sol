// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { IMitosisLedger } from '../../src/interfaces/hub/core/IMitosisLedger.sol';
import { MitosisLedger } from '../../src/hub/core/MitosisLedger.sol';
import { StdError } from '../../src/lib/StdError.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract TestCrossChainRegistry is Test, Toolkit {
  MitosisLedger internal mitosisLedger;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = _addr('owner');

  function setUp() public {
    vm.startPrank(owner);
    _proxyAdmin = new ProxyAdmin(owner);

    MitosisLedger mitosisLedgerImpl = new MitosisLedger();
    mitosisLedger = MitosisLedger(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(mitosisLedgerImpl), address(_proxyAdmin), abi.encodeCall(mitosisLedger.initialize, (owner))
          )
        )
      )
    );
    vm.stopPrank();
  }

  function test_recordDeposit() public {
    uint256 chainId = 1;
    uint256 amount = 100 ether;

    address asset1 = address(1);
    mitosisLedger.recordDeposit(chainId, asset1, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset1), amount);
    mitosisLedger.recordDeposit(chainId, asset1, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset1), 2 * amount);

    mitosisLedger.recordDeposit(2000, asset1, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset1), 2 * amount);
    assertEq(mitosisLedger.getAssetAmount(2000, asset1), amount);

    address asset2 = address(2);
    mitosisLedger.recordDeposit(chainId, asset2, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset2), amount);
  }

  function test_recordWithdraw() public {
    uint256 chainId = 1;
    address asset1 = address(1);
    uint256 amount = 100 ether;

    vm.expectRevert(); // underflow
    mitosisLedger.recordWithdraw(chainId, asset1, amount);

    mitosisLedger.recordDeposit(chainId, asset1, 10 * amount);

    mitosisLedger.recordWithdraw(chainId, asset1, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset1), 9 * amount);
  }

  function test_recordOptIn() public {
    uint256 eolId = 1;
    uint256 amount = 100 ether;
    mitosisLedger.recordOptIn(eolId, amount);
    assertEq(mitosisLedger.getEOLAllocateAmount(eolId), amount);
  }

  function test_recordOptOut() public {
    uint256 eolId = 1;
    uint256 amount = 100 ether;

    mitosisLedger.recordOptIn(eolId, amount);

    uint256 optOutAmount = 10 ether;

    IMitosisLedger.EOLAmountState memory state;

    mitosisLedger.recordOptOutRequest(eolId, optOutAmount);
    state = mitosisLedger.eolAmountState(eolId);
    assertEq(mitosisLedger.getEOLAllocateAmount(eolId), amount - optOutAmount);
    assertEq(state.optOutPending, optOutAmount);

    mitosisLedger.recordDeallocateEOL(eolId, optOutAmount);
    state = mitosisLedger.eolAmountState(eolId);
    assertEq(mitosisLedger.getEOLAllocateAmount(eolId), amount - optOutAmount);
    assertEq(state.optOutPending, optOutAmount);
    assertEq(state.idle, optOutAmount);

    mitosisLedger.recordOptOutResolve(eolId, optOutAmount);
    state = mitosisLedger.eolAmountState(eolId);
    assertEq(mitosisLedger.getEOLAllocateAmount(eolId), amount - optOutAmount);
    assertEq(state.idle, 0);
    assertEq(state.optOutResolved, optOutAmount);

    mitosisLedger.recordOptOutClaim(eolId, optOutAmount);
    state = mitosisLedger.eolAmountState(eolId);
    assertEq(mitosisLedger.getEOLAllocateAmount(eolId), amount - optOutAmount);
    assertEq(state.optOutPending, 0);
    assertEq(state.idle, 0);
    assertEq(state.optOutResolved, 0);
    assertEq(state.total, amount - optOutAmount);
  }
}
