// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from '@std/Test.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { EOLVault } from '../../src/hub/core/EOLVault.sol';
import { HubAsset } from '../../src/hub/core/HubAsset.sol';
import { MitosisLedger } from '../../src/hub/core/MitosisLedger.sol';
import { OptOutQueue } from '../../src/hub/core/OptOutQueue.sol';
import { IERC20TwabSnapshots } from '../../src/interfaces/twab/IERC20TwabSnapshots.sol';
import { Toolkit } from '../util/Toolkit.sol';

contract OptOutQueueTest is Test, Toolkit {
  address internal _admin = _addr('admin');
  address internal _owner = _addr('owner');
  address internal _user = _addr('user');

  address internal _assetManager = _addr('assetManager'); // mock
  ERC1967Factory internal _factory;
  MitosisLedger internal _ledger;
  HubAsset internal _hubAsset;
  EOLVault internal _eolVault;
  OptOutQueue internal _optOutQueue;

  modifier withAccount(address account) {
    vm.startPrank(account);

    _;

    vm.stopPrank();
  }

  function setUp() public {
    _factory = new ERC1967Factory();

    _ledger = MitosisLedger(
      _proxy(
        address(new MitosisLedger()),
        abi.encodeCall(MitosisLedger.initialize, (_owner)) //
      )
    );
    _hubAsset = HubAsset(
      _proxy(
        address(new HubAsset()),
        abi.encodeCall(HubAsset.initialize, ('Test', 'TT')) //
      )
    );
    _eolVault = EOLVault(
      _proxy(
        address(new EOLVault()),
        abi.encodeCall(EOLVault.initialize, (IERC20TwabSnapshots(address(_hubAsset)), _ledger, 'miTest', 'miTT')) //
      )
    );
    _optOutQueue = OptOutQueue(
      _proxy(
        address(new OptOutQueue()),
        abi.encodeCall(OptOutQueue.initialize, (_owner, address(_ledger))) //
      )
    );

    // configure

    vm.startPrank(_owner);

    _ledger.setOptOutQueue(address(_optOutQueue));

    _optOutQueue.enable(address(_eolVault));
    _optOutQueue.setRedeemPeriod(address(_eolVault), 1 days);

    vm.stopPrank();

    // provide liquidity

    _optIn(_user, 1000 ether, true);
  }

  function test_onNormal() public {
    _optOutRequest(_user, 100 ether);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _optOutClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function test_onLossReported() public {
    _optOutRequest(_user, 100 ether);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _burn(address(_eolVault), 100 ether); // report loss
    _optOutClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function test_onYieldReported() public {
    _optOutRequest(_user, 100 ether);

    vm.warp(block.timestamp + _optOutQueue.redeemPeriod(address(_eolVault)));

    _mint(address(_eolVault), 100 ether); // report yield
    _optOutClaim(_user);

    vm.expectRevert(_errNothingToClaim());
    _optOutClaim(_user);
  }

  function _errQueueNotEnabled(address eolVault) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(OptOutQueue.OptOutQueue__QueueNotEnabled.selector, address(eolVault));
  }

  function _errNothingToClaim() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(OptOutQueue.OptOutQueue__NothingToClaim.selector);
  }

  function _proxy(address impl) internal returns (address) {
    return _factory.deploy(impl, _admin);
  }

  function _proxy(address impl, bytes memory data) internal returns (address) {
    return _factory.deployAndCall(impl, _admin, data);
  }

  function _mint(address to, uint256 amount) internal {
    vm.prank(_assetManager);
    _hubAsset.mint(to, amount);
  }

  function _burn(address from, uint256 amount) internal {
    vm.prank(_assetManager);
    _hubAsset.burn(from, amount);
  }

  function _optIn(address account, uint256 assets, bool mint) internal returns (uint256 shares) {
    if (mint) _mint(account, assets);
    shares = _optInInner(account, assets);

    vm.prank(address(_eolVault));
    _ledger.recordOptIn(address(_eolVault), shares);
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
}
