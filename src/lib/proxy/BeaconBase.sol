// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { ERC7201Utils } from '../ERC7201Utils.sol';

interface IBeaconBase {
  function beacon() external view returns (address);
  function isInstance(address instance) external view returns (bool);
  function instances(uint256 index) external view returns (address);
  function instances(uint256[] memory indexes) external view returns (address[] memory);
  function instancesLength() external view returns (uint256);
}

contract BeaconBase is IBeaconBase, ContextUpgradeable {
  using ERC7201Utils for string;

  struct BeaconBaseStorage {
    UpgradeableBeacon beacon;
    address[] instances;
    mapping(address => uint256) instanceIndex;
  }

  string private constant _NAMESPACE = 'mitosis.storage.BeaconBase';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getBeaconBaseStorage() private view returns (BeaconBaseStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  function __BeaconBase_init(UpgradeableBeacon beacon_) internal {
    __Context_init();
    BeaconBaseStorage storage $ = _getBeaconBaseStorage();
    $.beacon = beacon_;
  }

  function beacon() public view returns (address) {
    return address(_getBeaconBaseStorage().beacon);
  }

  function isInstance(address instance) external view returns (bool) {
    BeaconBaseStorage storage $ = _getBeaconBaseStorage();
    if ($.instances.length == 0) return false;

    uint256 index = $.instanceIndex[instance];
    if (index == 0 && $.instances[0] != instance) return false;

    return true;
  }

  function instances(uint256 index) external view returns (address) {
    return _getBeaconBaseStorage().instances[index];
  }

  function instances(uint256[] memory indexes) external view returns (address[] memory) {
    BeaconBaseStorage storage $ = _getBeaconBaseStorage();

    address[] memory result = new address[](indexes.length);
    for (uint256 i = 0; i < indexes.length; i++) {
      result[i] = $.instances[indexes[i]];
    }
    return result;
  }

  function instancesLength() external view returns (uint256) {
    return _getBeaconBaseStorage().instances.length;
  }

  function _callBeacon(bytes calldata data) internal returns (bytes memory) {
    (bool success, bytes memory result) = address(beacon()).call(data);
    require(success, 'TestTokenHub: call beacon failed');
    return result;
  }

  function _pushInstance(address instance) internal {
    BeaconBaseStorage storage $ = _getBeaconBaseStorage();
    $.instances.push(instance);
    $.instanceIndex[instance] = $.instances.length - 1;
  }
}
