// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MitosisLedger } from '../../src/hub/MitosisLedger.sol';

contract TestCrossChainRegistry is Test {
  MitosisLedger internal mitosisLedger;

  ProxyAdmin internal _proxyAdmin;

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);

    MitosisLedger mitosisLedgerImpl = new MitosisLedger();
    mitosisLedger = MitosisLedger(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(mitosisLedgerImpl),
            address(_proxyAdmin),
            abi.encodeWithSelector(mitosisLedger.initialize.selector, 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)
          )
        )
      )
    );
  }

  function test_recordDeposit() public {
    uint256 chainId = 1;
    uint256 amount = 100;

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
    uint256 amount = 100;

    vm.expectRevert(); // underflow
    mitosisLedger.recordWithdraw(chainId, asset1, amount);

    mitosisLedger.recordDeposit(chainId, asset1, 10 * amount);

    mitosisLedger.recordWithdraw(chainId, asset1, amount);
    assertEq(mitosisLedger.getAssetAmount(chainId, asset1), 9 * amount);
  }

  function test_recordOptIn() public {
    address miAsset = address(1);
    uint256 amount = 100;
    mitosisLedger.recordOptIn(miAsset, amount);
    assertEq(mitosisLedger.getEOLAllocateAmount(miAsset), amount);
  }

  function test_recordOptOut() public {
    address miAsset = address(1);
    uint256 amount = 100;

    mitosisLedger.recordOptIn(miAsset, amount);

    uint256 optOutAmount = 10;

    MitosisLedger.EOLState memory state;

    mitosisLedger.recordOptOutRequest(miAsset, optOutAmount);
    state = mitosisLedger.getEOLState(miAsset);
    assertEq(mitosisLedger.getEOLAllocateAmount(miAsset), amount - optOutAmount);
    assertEq(state.pending, optOutAmount);

    mitosisLedger.recordDeallocateEOL(miAsset, optOutAmount);
    state = mitosisLedger.getEOLState(miAsset);
    assertEq(mitosisLedger.getEOLAllocateAmount(miAsset), amount - optOutAmount);
    assertEq(state.pending, optOutAmount);
    assertEq(state.released, optOutAmount);

    mitosisLedger.recordOptOutResolve(miAsset, optOutAmount);
    state = mitosisLedger.getEOLState(miAsset);
    assertEq(mitosisLedger.getEOLAllocateAmount(miAsset), amount - optOutAmount);
    assertEq(state.released, 0);
    assertEq(state.resolved, optOutAmount);

    mitosisLedger.recordOptOutClaim(miAsset, optOutAmount);
    state = mitosisLedger.getEOLState(miAsset);
    assertEq(mitosisLedger.getEOLAllocateAmount(miAsset), amount - optOutAmount);
    assertEq(state.pending, 0);
    assertEq(state.released, 0);
    assertEq(state.resolved, 0);
    assertEq(state.finalized, amount - optOutAmount);
  }
}
