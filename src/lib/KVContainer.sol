// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

contract KVContainerStorageV1 {
  struct StorageV1 {
    mapping(bytes32 => string) stringStorage;
    mapping(bytes32 => bytes) bytesStorage;
    mapping(bytes32 => uint256) uintStorage;
    mapping(bytes32 => int256) intStorage;
    mapping(bytes32 => address) addressStorage;
    mapping(bytes32 => bool) booleanStorage;
    mapping(bytes32 => bytes32) bytes32Storage;
  }

  // keccak256(abi.encode(uint256(keccak256("mitosis-protocol.storage.KVContainer.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0x18443ae32b65d0ca5994d07fa39e9e5ecef9c60a30749b86249e2b800c7e9700;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}

contract KVContainer is Ownable2StepUpgradeable, KVContainerStorageV1 {
  //=========== merge OwnableUpgradeable & Ownable2StepUpgradeable

  function transferOwnership(address owner) public override {
    Ownable2StepUpgradeable.transferOwnership(owner);
  }

  function _transferOwnership(address owner) internal override {
    Ownable2StepUpgradeable._transferOwnership(owner);
  }

  //===========

  function initialize(address owner) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  // Query Functions

  function getAddress(bytes32 _key) external view returns (address r) {
    return _getStorageV1().addressStorage[_key];
  }

  /// @param _key The key for the record
  function getUint(bytes32 _key) external view returns (uint256 r) {
    return _getStorageV1().uintStorage[_key];
  }

  /// @param _key The key for the record
  function getString(bytes32 _key) external view returns (string memory) {
    return _getStorageV1().stringStorage[_key];
  }

  /// @param _key The key for the record
  function getBytes(bytes32 _key) external view returns (bytes memory) {
    return _getStorageV1().bytesStorage[_key];
  }

  /// @param _key The key for the record
  function getBool(bytes32 _key) external view returns (bool r) {
    return _getStorageV1().booleanStorage[_key];
  }

  /// @param _key The key for the record
  function getInt(bytes32 _key) external view returns (int256 r) {
    return _getStorageV1().intStorage[_key];
  }

  /// @param _key The key for the record
  function getBytes32(bytes32 _key) external view returns (bytes32 r) {
    return _getStorageV1().bytes32Storage[_key];
  }

  // Mutative functions

  /// @param _key The key for the record
  function setAddress(bytes32 _key, address _value) external {
    _getStorageV1().addressStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setUint(bytes32 _key, uint256 _value) external {
    _getStorageV1().uintStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setString(bytes32 _key, string calldata _value) external {
    _getStorageV1().stringStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBytes(bytes32 _key, bytes calldata _value) external {
    _getStorageV1().bytesStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBool(bytes32 _key, bool _value) external {
    _getStorageV1().booleanStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setInt(bytes32 _key, int256 _value) external {
    _getStorageV1().intStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBytes32(bytes32 _key, bytes32 _value) external {
    _getStorageV1().bytes32Storage[_key] = _value;
  }

  /// @param _key The key for the record
  function deleteAddress(bytes32 _key) external {
    delete _getStorageV1().addressStorage[_key];
  }

  /// @param _key The key for the record
  function deleteUint(bytes32 _key) external {
    delete _getStorageV1().uintStorage[_key];
  }

  /// @param _key The key for the record
  function deleteString(bytes32 _key) external {
    delete _getStorageV1().stringStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBytes(bytes32 _key) external {
    delete _getStorageV1().bytesStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBool(bytes32 _key) external {
    delete _getStorageV1().booleanStorage[_key];
  }

  /// @param _key The key for the record
  function deleteInt(bytes32 _key) external {
    delete _getStorageV1().intStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBytes32(bytes32 _key) external {
    delete _getStorageV1().bytes32Storage[_key];
  }
}
