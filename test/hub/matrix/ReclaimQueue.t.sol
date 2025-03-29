// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';
import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';
import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';
import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';

import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { ReclaimQueue } from '../../../src/hub/matrix/ReclaimQueue.sol';
import { IAssetManager } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IReclaimQueue } from '../../../src/interfaces/hub/matrix/IReclaimQueue.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ReclaimQueueTest is Toolkit {
  address internal _admin = makeAddr('admin');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  MockContract internal assetManager;
  MockContract internal hubAsset;
  MockContract internal matrixVault;
  ReclaimQueue internal reclaimQueue;

  modifier withAccount(address account) {
    vm.startPrank(account);

    _;

    vm.stopPrank();
  }

  function setUp() public {
    assetManager = new MockContract();

    hubAsset = new MockContract();
    hubAsset.setCall(IERC20.transfer.selector);
    hubAsset.setRet(abi.encodeCall(IERC20Metadata.decimals, ()), false, abi.encode(18));

    matrixVault = new MockContract();
    matrixVault.setCall(IERC20.transfer.selector);
    matrixVault.setCall(IERC20.transferFrom.selector);
    matrixVault.setCall(IERC4626.withdraw.selector);
    matrixVault.setRet(abi.encodeCall(IERC4626.asset, ()), false, abi.encode(address(hubAsset)));
    matrixVault.setRet(abi.encodeCall(IERC20Metadata.decimals, ()), false, abi.encode(18));

    reclaimQueue = ReclaimQueue(
      payable(
        _proxy(
          address(new ReclaimQueue()),
          abi.encodeCall(ReclaimQueue.initialize, (_owner, address(assetManager))) //
        )
      )
    );
  }

  function _enable(address matrixVault_, uint256 reclaimPeriod_) internal {
    vm.startPrank(_owner);
    reclaimQueue.enable(address(matrixVault_));
    reclaimQueue.setRedeemPeriod(address(matrixVault_), reclaimPeriod_);
    vm.stopPrank();
  }

  function test_onNormal() public {
    vm.prank(_user);
    vm.expectRevert(_errQueueNotEnabled(address(matrixVault)));
    reclaimQueue.request(100 ether, _user, address(matrixVault));

    _enable(address(matrixVault), 1 days);

    // request
    matrixVault.setRet(
      abi.encodeCall(IERC20.transferFrom, (_user, address(reclaimQueue), 100 ether)), false, abi.encode(true)
    );
    matrixVault.setRet(abi.encodeCall(IERC4626.previewRedeem, (100 ether)), false, abi.encode(100 ether));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequested(_user, address(matrixVault), 100 ether, 100 ether - 1);
    reclaimQueue.request(100 ether, _user, address(matrixVault));

    matrixVault.assertLastCall(abi.encodeCall(IERC20.transferFrom, (_user, address(reclaimQueue), 100 ether)));

    // claim - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));

    // wait for redeem period
    vm.warp(block.timestamp + reclaimQueue.redeemPeriod(address(matrixVault)));

    // sync
    matrixVault.setRet(abi.encodeCall(IERC20.totalSupply, ()), false, abi.encode(100 ether - 1));
    matrixVault.setRet(abi.encodeCall(IERC4626.totalAssets, ()), false, abi.encode(100 ether - 1));
    matrixVault.setRet(
      abi.encodeCall(IERC4626.withdraw, (100 ether - 1, address(reclaimQueue), address(reclaimQueue))),
      false,
      abi.encode(100 ether - 1)
    );
    vm.prank(address(assetManager));
    vm.expectEmit();
    emit IReclaimQueue.ReserveSynced(address(assetManager), address(matrixVault), 1, 100 ether, 100 ether - 1);
    reclaimQueue.sync(address(assetManager), address(matrixVault), 1);

    matrixVault.assertLastCall(
      abi.encodeCall(IERC4626.withdraw, (100 ether - 1, address(reclaimQueue), address(reclaimQueue)))
    );

    // claim
    matrixVault.setRet(abi.encodeCall(IERC20.transfer, (_user, 100 ether - 1)), false, abi.encode(true));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(matrixVault), 100 ether - 1);
    reclaimQueue.claim(_user, address(matrixVault));

    hubAsset.assertLastCall(abi.encodeCall(IERC20.transfer, (_user, 100 ether - 1)));

    // claim again - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));
  }

  function test_onLossReported() public {
    _enable(address(matrixVault), 1 days);

    // request
    matrixVault.setRet(
      abi.encodeCall(IERC20.transferFrom, (_user, address(reclaimQueue), 100 ether)), false, abi.encode(true)
    );
    matrixVault.setRet(abi.encodeCall(IERC4626.previewRedeem, (100 ether)), false, abi.encode(100 ether));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequested(_user, address(matrixVault), 100 ether, 100 ether - 1);
    reclaimQueue.request(100 ether, _user, address(matrixVault));

    // claim - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));

    // wait for redeem period
    vm.warp(block.timestamp + reclaimQueue.redeemPeriod(address(matrixVault)));

    // sync with loss
    matrixVault.setRet(abi.encodeCall(IERC20.totalSupply, ()), false, abi.encode(100 ether - 1));
    matrixVault.setRet(abi.encodeCall(IERC4626.totalAssets, ()), false, abi.encode(90 ether)); // 10% loss
    matrixVault.setRet(
      abi.encodeCall(IERC4626.withdraw, (90 ether + 1, address(reclaimQueue), address(reclaimQueue))),
      false,
      abi.encode(90 ether)
    );
    vm.prank(address(assetManager));
    vm.expectEmit();
    emit IReclaimQueue.ReserveSynced(address(assetManager), address(matrixVault), 1, 100 ether, 90 ether + 1);
    reclaimQueue.sync(address(assetManager), address(matrixVault), 1);

    // claim
    hubAsset.setRet(abi.encodeCall(IERC20.transfer, (_user, 90 ether + 1)), false, abi.encode(true));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(matrixVault), 90 ether + 1);
    reclaimQueue.claim(_user, address(matrixVault));

    hubAsset.assertLastCall(abi.encodeCall(IERC20.transfer, (_user, 90 ether + 1)));

    // claim again - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));
  }

  function test_onYieldReported() public {
    _enable(address(matrixVault), 1 days);

    // request
    matrixVault.setRet(
      abi.encodeCall(IERC20.transferFrom, (_user, address(reclaimQueue), 100 ether)), false, abi.encode(true)
    );
    matrixVault.setRet(abi.encodeCall(IERC4626.previewRedeem, (100 ether)), false, abi.encode(100 ether));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequested(_user, address(matrixVault), 100 ether, 100 ether - 1);
    reclaimQueue.request(100 ether, _user, address(matrixVault));

    // claim - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));

    // wait for redeem period
    vm.warp(block.timestamp + reclaimQueue.redeemPeriod(address(matrixVault)));

    // sync with yield
    matrixVault.setRet(abi.encodeCall(IERC20.totalSupply, ()), false, abi.encode(100 ether - 1));
    matrixVault.setRet(abi.encodeCall(IERC4626.totalAssets, ()), false, abi.encode(100 ether - 1));
    matrixVault.setRet(
      abi.encodeCall(IERC4626.withdraw, (100 ether - 1, address(reclaimQueue), address(reclaimQueue))),
      false,
      abi.encode(100 ether - 1)
    );
    vm.prank(address(assetManager));
    vm.expectEmit();
    emit IReclaimQueue.ReserveSynced(address(assetManager), address(matrixVault), 1, 100 ether, 100 ether - 1);
    reclaimQueue.sync(address(assetManager), address(matrixVault), 1);

    // claim
    matrixVault.setRet(abi.encodeCall(IERC20.transfer, (_user, 100 ether - 1)), false, abi.encode(true));
    vm.prank(_user);
    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(matrixVault), 100 ether - 1);
    reclaimQueue.claim(_user, address(matrixVault));

    hubAsset.assertLastCall(abi.encodeCall(IERC20.transfer, (_user, 100 ether - 1)));

    // claim again - should revert
    vm.prank(_user);
    vm.expectRevert(_errNothingToClaim());
    reclaimQueue.claim(_user, address(matrixVault));
  }

  function _errQueueNotEnabled(address matrixVault_) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IReclaimQueue.IReclaimQueue__QueueNotEnabled.selector, address(matrixVault_));
  }

  function _errNothingToClaim() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IReclaimQueue.IReclaimQueue__NothingToClaim.selector);
  }
}
