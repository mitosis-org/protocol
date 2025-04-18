// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { IMatrixVaultFactory } from '../../interfaces/hub/matrix/IMatrixVaultFactory.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { BeaconProxy, IBeaconProxy } from '../../lib/proxy/BeaconProxy.sol';
import { StdError } from '../../lib/StdError.sol';
import { MatrixVaultBasic } from './MatrixVaultBasic.sol';
import { MatrixVaultCapped } from './MatrixVaultCapped.sol';

contract MatrixVaultFactory is IMatrixVaultFactory, Ownable2StepUpgradeable, UUPSUpgradeable {
  using ERC7201Utils for string;

  struct BeaconInfo {
    bool initialized;
    address beacon;
    address[] instances;
    mapping(address => uint256) instanceIndex;
  }

  struct Storage {
    mapping(address instance => bool) isInstance;
    mapping(VaultType vaultType => BeaconInfo) infos;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MatrixVaultFactory';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorage() private view returns (Storage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  uint8 public constant MAX_VAULT_TYPE = uint8(VaultType.Capped);

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
  }

  function beacon(uint8 t) external view returns (address) {
    return address(_getStorage().infos[_safeVaultTypeCast(t)].beacon);
  }

  function isInstance(address instance) external view returns (bool) {
    return _getStorage().isInstance[instance];
  }

  function isInstance(uint8 t, address instance) external view returns (bool) {
    return _isInstance(_getStorage(), _safeVaultTypeCast(t), instance);
  }

  function instances(uint8 t, uint256 index) external view returns (address) {
    return _getStorage().infos[_safeVaultTypeCast(t)].instances[index];
  }

  function instances(uint8 t, uint256[] memory indexes) external view returns (address[] memory) {
    BeaconInfo storage info = _getStorage().infos[_safeVaultTypeCast(t)];

    address[] memory result = new address[](indexes.length);
    for (uint256 i = 0; i < indexes.length; i++) {
      result[i] = info.instances[indexes[i]];
    }
    return result;
  }

  function instancesLength(uint8 t) external view returns (uint256) {
    return _getStorage().infos[_safeVaultTypeCast(t)].instances.length;
  }

  function initVaultType(uint8 rawVaultType, address initialImpl) external onlyOwner {
    VaultType vaultType = _safeVaultTypeCast(rawVaultType);
    require(vaultType != VaultType.Unset, IMatrixVaultFactory__InvalidVaultType());

    Storage storage $ = _getStorage();
    require(!$.infos[vaultType].initialized, IMatrixVaultFactory__AlreadyInitialized());

    $.infos[vaultType].initialized = true;
    $.infos[vaultType].beacon = address(new UpgradeableBeacon(address(this), initialImpl));

    emit VaultTypeInitialized(vaultType, address($.infos[vaultType].beacon));
  }

  function vaultTypeInitialized(uint8 t) external view returns (bool) {
    return _getStorage().infos[_safeVaultTypeCast(t)].initialized;
  }

  /**
   * @dev used to migrate the beacon implementation - see `UpgradeableBeacon.upgradeTo`
   */
  function callBeacon(uint8 t, bytes calldata data) external onlyOwner returns (bytes memory) {
    Storage storage $ = _getStorage();
    VaultType vaultType = _safeVaultTypeCast(t);
    require($.infos[vaultType].initialized, IMatrixVaultFactory__NotInitialized());

    (bool success, bytes memory result) = address($.infos[vaultType].beacon).call(data);
    require(success, IMatrixVaultFactory__CallBeaconFailed(result));

    emit BeaconCalled(_msgSender(), vaultType, data, success, result);

    return result;
  }

  function create(uint8 t, bytes calldata args) external onlyOwner returns (address) {
    Storage storage $ = _getStorage();
    VaultType vaultType = _safeVaultTypeCast(t);
    require($.infos[vaultType].initialized, IMatrixVaultFactory__NotInitialized());

    address instance;

    if (vaultType == VaultType.Basic) instance = _create($, abi.decode(args, (BasicVaultInitArgs)));
    else if (vaultType == VaultType.Capped) instance = _create($, abi.decode(args, (CappedVaultInitArgs)));
    else revert IMatrixVaultFactory__InvalidVaultType();

    $.isInstance[instance] = true;

    emit MatrixVaultCreated(vaultType, instance, args);
    return instance;
  }

  function migrate(uint8 from, uint8 to, address instance, bytes calldata data) external onlyOwner {
    Storage storage $ = _getStorage();
    VaultType fromVaultType = _safeVaultTypeCast(from);
    VaultType toVaultType = _safeVaultTypeCast(to);
    BeaconInfo storage fromInfo = $.infos[fromVaultType];
    BeaconInfo storage toInfo = $.infos[toVaultType];

    require(fromInfo.initialized, IMatrixVaultFactory__NotInitialized());
    require(toInfo.initialized, IMatrixVaultFactory__NotInitialized());
    require(_isInstance($, fromVaultType, instance), IMatrixVaultFactory__NotAnInstance());

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

    emit MatrixVaultMigrated(fromVaultType, toVaultType, instance);
  }

  function _isInstance(Storage storage $, VaultType t, address instance) private view returns (bool) {
    if (!$.infos[t].initialized) return false;
    if ($.infos[t].instances.length == 0) return false;
    uint256 index = $.infos[t].instanceIndex[instance];
    return !(index == 0 && $.infos[t].instances[index] != instance);
  }

  function _create(Storage storage $, BasicVaultInitArgs memory args) private returns (address) {
    BeaconInfo storage info = $.infos[VaultType.Basic];

    bytes memory data = abi.encodeCall(
      MatrixVaultBasic.initialize, //
      (args.owner, args.assetManager, args.asset, args.name, args.symbol)
    );
    address instance = address(new BeaconProxy(address(info.beacon), data));

    info.instances.push(instance);
    info.instanceIndex[instance] = info.instances.length - 1;

    return instance;
  }

  function _create(Storage storage $, CappedVaultInitArgs memory args) private returns (address) {
    BeaconInfo storage info = $.infos[VaultType.Capped];

    bytes memory data = abi.encodeCall(
      MatrixVaultCapped.initialize, //
      (args.owner, args.assetManager, args.asset, args.name, args.symbol)
    );
    address instance = address(new BeaconProxy(address(info.beacon), data));

    info.instances.push(instance);
    info.instanceIndex[instance] = info.instances.length - 1;

    return instance;
  }

  function _safeVaultTypeCast(uint8 vaultType) internal pure returns (VaultType) {
    require(vaultType <= MAX_VAULT_TYPE, StdError.EnumOutOfBounds(MAX_VAULT_TYPE, vaultType));
    return VaultType(vaultType);
  }

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
