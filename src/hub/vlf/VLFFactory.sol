// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.23 <0.9.0;

import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { IVLFFactory } from '../../interfaces/hub/vlf/IVLFFactory.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { BeaconProxy, IBeaconProxy } from '../../lib/proxy/BeaconProxy.sol';
import { StdError } from '../../lib/StdError.sol';
import { Versioned } from '../../lib/Versioned.sol';
import { VLFBasic } from './VLFBasic.sol';
import { VLFCapped } from './VLFCapped.sol';

contract VLFFactory is IVLFFactory, Ownable2StepUpgradeable, UUPSUpgradeable, Versioned {
  using ERC7201Utils for string;

  struct BeaconInfo {
    bool initialized;
    address beacon;
    address[] instances;
    mapping(address => uint256) instanceIndex;
  }

  struct Storage {
    mapping(address instance => bool) isInstance;
    mapping(VLFType vlfType => BeaconInfo) infos;
  }

  string private constant _NAMESPACE = 'mitosis.storage.VLFFactory';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorage() private view returns (Storage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  uint8 public constant MAX_VLF_TYPE = uint8(VLFType.Capped);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
  }

  function beacon(uint8 t) external view returns (address) {
    return address(_getStorage().infos[_safeVLFTypeCast(t)].beacon);
  }

  function isInstance(address instance) external view returns (bool) {
    return _getStorage().isInstance[instance];
  }

  function isInstance(uint8 t, address instance) external view returns (bool) {
    return _isInstance(_getStorage(), _safeVLFTypeCast(t), instance);
  }

  function instances(uint8 t, uint256 index) external view returns (address) {
    return _getStorage().infos[_safeVLFTypeCast(t)].instances[index];
  }

  function instances(uint8 t, uint256[] memory indexes) external view returns (address[] memory) {
    BeaconInfo storage info = _getStorage().infos[_safeVLFTypeCast(t)];

    address[] memory result = new address[](indexes.length);
    for (uint256 i = 0; i < indexes.length; i++) {
      result[i] = info.instances[indexes[i]];
    }
    return result;
  }

  function instancesLength(uint8 t) external view returns (uint256) {
    return _getStorage().infos[_safeVLFTypeCast(t)].instances.length;
  }

  function initVLFType(uint8 rawVaultType, address initialImpl) external onlyOwner {
    VLFType vlfType = _safeVLFTypeCast(rawVaultType);
    require(vlfType != VLFType.Unset, IVLFFactory__InvalidVLFType());

    Storage storage $ = _getStorage();
    require(!$.infos[vlfType].initialized, IVLFFactory__AlreadyInitialized());

    $.infos[vlfType].initialized = true;
    $.infos[vlfType].beacon = address(new UpgradeableBeacon(address(this), initialImpl));

    emit VLFTypeInitialized(vlfType, address($.infos[vlfType].beacon));
  }

  function vlfTypeInitialized(uint8 t) external view returns (bool) {
    return _getStorage().infos[_safeVLFTypeCast(t)].initialized;
  }

  /**
   * @dev used to migrate the beacon implementation - see `UpgradeableBeacon.upgradeTo`
   */
  function callBeacon(uint8 t, bytes calldata data) external onlyOwner returns (bytes memory) {
    Storage storage $ = _getStorage();
    VLFType vlfType = _safeVLFTypeCast(t);
    require($.infos[vlfType].initialized, IVLFFactory__NotInitialized());

    (bool success, bytes memory result) = address($.infos[vlfType].beacon).call(data);
    require(success, IVLFFactory__CallBeaconFailed(result));

    emit BeaconCalled(_msgSender(), vlfType, data, success, result);

    return result;
  }

  function create(uint8 t, bytes calldata args) external onlyOwner returns (address) {
    Storage storage $ = _getStorage();
    VLFType vlfType = _safeVLFTypeCast(t);
    require($.infos[vlfType].initialized, IVLFFactory__NotInitialized());

    address instance;

    if (vlfType == VLFType.Basic) instance = _create($, abi.decode(args, (BasicVLFInitArgs)));
    else if (vlfType == VLFType.Capped) instance = _create($, abi.decode(args, (CappedVLFInitArgs)));
    else revert IVLFFactory__InvalidVLFType();

    $.isInstance[instance] = true;

    emit VLFCreated(vlfType, instance, args);
    return instance;
  }

  function migrate(uint8 from, uint8 to, address instance, bytes calldata data) external onlyOwner {
    Storage storage $ = _getStorage();
    VLFType fromVaultType = _safeVLFTypeCast(from);
    VLFType toVaultType = _safeVLFTypeCast(to);
    BeaconInfo storage fromInfo = $.infos[fromVaultType];
    BeaconInfo storage toInfo = $.infos[toVaultType];

    require(fromInfo.initialized, IVLFFactory__NotInitialized());
    require(toInfo.initialized, IVLFFactory__NotInitialized());
    require(_isInstance($, fromVaultType, instance), IVLFFactory__NotAnInstance());

    // Remove instance from 'from' type's tracking
    uint256 index = fromInfo.instanceIndex[instance];
    if (fromInfo.instances.length > 1) {
      // Move last element to the removed index and update its index mapping
      address last = fromInfo.instances[fromInfo.instances.length - 1];
      fromInfo.instances[index] = last;
      fromInfo.instanceIndex[last] = index;
    }
    fromInfo.instances.pop();
    delete fromInfo.instanceIndex[instance]; // Use delete instead of setting to 0

    toInfo.instances.push(instance);
    toInfo.instanceIndex[instance] = toInfo.instances.length - 1;
    IBeaconProxy(instance).upgradeBeaconToAndCall(toInfo.beacon, data);

    emit VLFMigrated(fromVaultType, toVaultType, instance);
  }

  function _isInstance(Storage storage $, VLFType t, address instance) private view returns (bool) {
    if (!$.infos[t].initialized) return false;
    if ($.infos[t].instances.length == 0) return false;
    uint256 index = $.infos[t].instanceIndex[instance];
    return !(index == 0 && $.infos[t].instances[index] != instance);
  }

  function _create(Storage storage $, BasicVLFInitArgs memory args) private returns (address) {
    BeaconInfo storage info = $.infos[VLFType.Basic];

    bytes memory data = abi.encodeCall(
      VLFBasic.initialize, //
      (args.assetManager, args.asset, args.name, args.symbol)
    );
    address instance = address(new BeaconProxy(address(info.beacon), data));

    info.instances.push(instance);
    info.instanceIndex[instance] = info.instances.length - 1;

    return instance;
  }

  function _create(Storage storage $, CappedVLFInitArgs memory args) private returns (address) {
    BeaconInfo storage info = $.infos[VLFType.Capped];

    bytes memory data = abi.encodeCall(
      VLFCapped.initialize, //
      (args.assetManager, args.asset, args.name, args.symbol)
    );
    address instance = address(new BeaconProxy(address(info.beacon), data));

    info.instances.push(instance);
    info.instanceIndex[instance] = info.instances.length - 1;

    return instance;
  }

  function _safeVLFTypeCast(uint8 vlfType) internal pure returns (VLFType) {
    require(vlfType <= MAX_VLF_TYPE, StdError.EnumOutOfBounds(MAX_VLF_TYPE, vlfType));
    return VLFType(vlfType);
  }

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
