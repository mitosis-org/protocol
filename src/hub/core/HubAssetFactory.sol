// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { BeaconProxy } from '@oz-v5/proxy/beacon/BeaconProxy.sol';

import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { BeaconBase } from '../../lib/proxy/BeaconBase.sol';
import { HubAsset } from './HubAsset.sol';

contract HubAssetFactory is BeaconBase, OwnableUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, address initialImpl) external initializer {
    __Ownable_init(owner_);
    __BeaconBase_init(new UpgradeableBeacon(address(this), address(initialImpl)));
  }

  function create(address owner_, address supplyManager, string memory name, string memory symbol, uint8 decimals)
    external
    onlyOwner
    returns (address)
  {
    bytes memory args = abi.encodeCall(HubAsset.initialize, (owner_, supplyManager, name, symbol, decimals));
    address instance = address(new BeaconProxy(address(beacon()), args));

    _pushInstance(instance);

    return instance;
  }

  function callBeacon(bytes calldata data) external onlyOwner returns (bytes memory) {
    return _callBeacon(data);
  }
}
