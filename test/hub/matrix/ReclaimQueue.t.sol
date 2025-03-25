// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';
import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';

import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { ReclaimQueue } from '../../../src/hub/matrix/ReclaimQueue.sol';
import { IAssetManager } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IReclaimQueue } from '../../../src/interfaces/hub/matrix/IReclaimQueue.sol';
import { MockAssetManager } from '../../mock/MockAssetManager.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ReclaimQueueTest is Toolkit {
  address internal _admin = makeAddr('admin');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  MockAssetManager internal _assetManager;
  HubAsset internal _hubAsset;
  MatrixVaultBasic internal _matrixVault;
  ReclaimQueue internal _reclaimQueue;

  modifier withAccount(address account) {
    vm.startPrank(account);

    _;

    vm.stopPrank();
  }

  function setUp() public {
    _assetManager = new MockAssetManager();

    _reclaimQueue = ReclaimQueue(
      payable(
        new ERC1967Proxy(
          address(new ReclaimQueue()),
          abi.encodeCall(ReclaimQueue.initialize, (_owner, address(_assetManager))) //
        )
      )
    );

    vm.prank(_owner);
    _assetManager.setReclaimQueue(address(_reclaimQueue));

    _hubAsset = HubAsset(
      _proxy(
        address(new HubAsset()),
        abi.encodeCall(HubAsset.initialize, (_owner, address(_assetManager), 'Test', 'TT', 18)) //
      )
    );
    _matrixVault = MatrixVaultBasic(
      _proxy(
        address(new MatrixVaultBasic()),
        abi.encodeCall(
          MatrixVaultBasic.initialize,
          (_owner, address(_assetManager), IERC20Metadata(address(_hubAsset)), 'miTest', 'miTT')
        ) //
      )
    );

    // configure

    vm.startPrank(_owner);

    _reclaimQueue.enable(address(_matrixVault));
    _reclaimQueue.setRedeemPeriod(address(_matrixVault), 1 days);

    vm.stopPrank();

    // provide liquidity

    _supply(_user, 1000 ether, true);
  }

  function test_onNormal() public {
    _reclaimRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);

    vm.warp(block.timestamp + _reclaimQueue.redeemPeriod(address(_matrixVault)));

    _reclaimReserve(1);

    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(_matrixVault), 100 ether - 1);
    _reclaimClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);
  }

  function test_onLossReported() public {
    _reclaimRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);

    vm.warp(block.timestamp + _reclaimQueue.redeemPeriod(address(_matrixVault)));

    _burn(address(_matrixVault), 100 ether); // report loss
    _reclaimReserve(1);

    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(_matrixVault), 90 ether);
    _reclaimClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);
  }

  function test_onYieldReported() public {
    _reclaimRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);

    vm.warp(block.timestamp + _reclaimQueue.redeemPeriod(address(_matrixVault)));

    _mint(address(_matrixVault), 100 ether); // report yield
    _reclaimReserve(1);

    vm.expectEmit();
    emit IReclaimQueue.ReclaimRequestClaimed(_user, address(_matrixVault), 100 ether - 1);

    _reclaimClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _reclaimClaim(_user);
  }

  function _errQueueNotEnabled(address matrixVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IReclaimQueue.IReclaimQueue__QueueNotEnabled.selector, address(matrixVault));
  }

  function _errNothingToClaim() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IReclaimQueue.IReclaimQueue__NothingToClaim.selector);
  }

  function _mint(address to, uint256 amount) internal {
    vm.prank(address(_assetManager));
    _hubAsset.mint(to, amount);
  }

  function _burn(address from, uint256 amount) internal {
    vm.prank(address(_assetManager));
    _hubAsset.burn(from, amount);
  }

  function _supply(address account, uint256 assets, bool mint) internal returns (uint256 shares) {
    if (mint) _mint(account, assets);
    shares = _supplyInner(account, assets);

    return shares;
  }

  function _supplyInner(address account, uint256 assets) internal withAccount(account) returns (uint256 shares) {
    _hubAsset.approve(address(_matrixVault), assets);
    shares = _matrixVault.deposit(assets, account);
    return shares;
  }

  function _reclaimRequest(address account, uint256 shares) internal withAccount(account) returns (uint256 reqId) {
    _matrixVault.approve(address(_reclaimQueue), shares);
    reqId = _reclaimQueue.request(shares, account, address(_matrixVault));
    return reqId;
  }

  function _reclaimClaim(address account) internal withAccount(account) returns (uint256 totalClaimed) {
    totalClaimed = _reclaimQueue.claim(account, address(_matrixVault));
    return totalClaimed;
  }

  function _reclaimReserve(uint256 count) internal withAccount(address(_assetManager)) {
    _reclaimQueue.sync(msg.sender, address(_matrixVault), count);
  }
}
