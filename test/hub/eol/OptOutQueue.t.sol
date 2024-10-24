// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from '@std/Test.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { HubAsset } from '../../../src/hub/core/HubAsset.sol';
import { OptOutQueue } from '../../../src/hub/eol/OptOutQueue.sol';
import { EOLVaultBasic } from '../../../src/hub/eol/vault/EOLVaultBasic.sol';
import { IAssetManager } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IOptOutQueue } from '../../../src/interfaces/hub/eol/IOptOutQueue.sol';
import { IERC20TWABSnapshots } from '../../../src/interfaces/twab/IERC20TWABSnapshots.sol';
import { MockAssetManager } from '../../mock/MockAssetManager.t.sol';
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';

contract OptOutQueueTest is Test {
  address internal _admin = makeAddr('admin');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract

  MockAssetManager internal _assetManager;
  MockDelegationRegistry internal _delegationRegistry;
  ERC1967Factory internal _factory;
  HubAsset internal _hubAsset;
  EOLVaultBasic internal _eolVault;
  OptOutQueue internal _optOutQueue;

  modifier withAccount(address account) {
    vm.startPrank(account);

    _;

    vm.stopPrank();
  }

  function setUp() public {
    _factory = new ERC1967Factory();

    _assetManager = new MockAssetManager();
    _delegationRegistry = new MockDelegationRegistry(mitosis);

    _hubAsset = HubAsset(
      _proxy(
        address(new HubAsset()),
        abi.encodeCall(HubAsset.initialize, (_owner, address(_assetManager), address(_delegationRegistry), 'Test', 'TT')) //
      )
    );
    _eolVault = EOLVaultBasic(
      _proxy(
        address(new EOLVaultBasic()),
        abi.encodeCall(
          EOLVaultBasic.initialize,
          (
            address(_delegationRegistry),
            address(_assetManager),
            IERC20TWABSnapshots(address(_hubAsset)),
            'miTest',
            'miTT'
          )
        ) //
      )
    );
    _optOutQueue = OptOutQueue(
      _proxy(
        address(new OptOutQueue()),
        abi.encodeCall(OptOutQueue.initialize, (_owner, address(_assetManager))) //
      )
    );

    // configure

    vm.startPrank(_owner);

    _assetManager.setOptOutQueue(address(_optOutQueue));
    _optOutQueue.enable(address(_eolVault));
    _optOutQueue.setRedeemPeriod(address(_eolVault), 1 days);

    vm.stopPrank();

    // provide liquidity

    _optIn(_user, 1000 ether, true);
  }

  function test_onNormal() public {
    _optOutRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _optOutReserve(100 ether);
    _optOutClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function test_onLossReported() public {
    _optOutRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _burn(address(_eolVault), 100 ether); // report loss
    _optOutReserve(90 ether);

    // FIXME: declare share burn amount?
    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function test_onYieldReported() public {
    _optOutRequest(_user, 100 ether);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _mint(address(_eolVault), 100 ether); // report yield
    _optOutReserve(100 ether);
    _optOutClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function _errQueueNotEnabled(address eolVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IOptOutQueue.IOptOutQueue__QueueNotEnabled.selector, address(eolVault));
  }

  function _errNothingToClaim() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IOptOutQueue.IOptOutQueue__NothingToClaim.selector);
  }

  function _proxy(address impl) internal returns (address) {
    return _factory.deploy(impl, _admin);
  }

  function _proxy(address impl, bytes memory data) internal returns (address) {
    return _factory.deployAndCall(impl, _admin, data);
  }

  function _mint(address to, uint256 amount) internal {
    vm.prank(address(_assetManager));
    _hubAsset.mint(to, amount);
  }

  function _burn(address from, uint256 amount) internal {
    vm.prank(address(_assetManager));
    _hubAsset.burn(from, amount);
  }

  function _optIn(address account, uint256 assets, bool mint) internal returns (uint256 shares) {
    if (mint) _mint(account, assets);
    shares = _optInInner(account, assets);

    return shares;
  }

  function _optInInner(address account, uint256 assets) internal withAccount(account) returns (uint256 shares) {
    _hubAsset.approve(address(_eolVault), assets);
    shares = _eolVault.deposit(assets, account);
    return shares;
  }

  function _optOutRequest(address account, uint256 shares) internal withAccount(account) returns (uint256 reqId) {
    _eolVault.approve(address(_optOutQueue), shares);
    reqId = _optOutQueue.request(shares, account, address(_eolVault));
    return reqId;
  }

  function _optOutClaim(address account) internal withAccount(account) returns (uint256 totalClaimed) {
    totalClaimed = _optOutQueue.claim(account, address(_eolVault));
    return totalClaimed;
  }

  function _optOutReserve(uint256 amount) internal withAccount(address(_assetManager)) {
    _optOutQueue.sync(address(_eolVault), amount);
  }
}
