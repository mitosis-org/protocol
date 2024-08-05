// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Storage } from '../lib/Storage.sol';

abstract contract RegistryBase {
  Storage _storage;

  /// @dev Storage get methods
  function _getAddress(bytes32 _key) internal view returns (address) {
    return _storage.getAddress(_key);
  }

  function _getUint(bytes32 _key) internal view returns (uint256) {
    return _storage.getUint(_key);
  }

  function _getString(bytes32 _key) internal view returns (string memory) {
    return _storage.getString(_key);
  }

  function _getBytes(bytes32 _key) internal view returns (bytes memory) {
    return _storage.getBytes(_key);
  }

  function _getBool(bytes32 _key) internal view returns (bool) {
    return _storage.getBool(_key);
  }

  function _getInt(bytes32 _key) internal view returns (int256) {
    return _storage.getInt(_key);
  }

  function _getBytes32(bytes32 _key) internal view returns (bytes32) {
    return _storage.getBytes32(_key);
  }

  /// @dev
  function _isZeroAddress(bytes32 _key) internal view returns (bool) {
    return _getAddress(_key) == address(0);
  }

  function _isZeroUint(bytes32 _key) internal view returns (bool) {
    return _getUint(_key) == 0;
  }

  function _isZeroString(bytes32 _key) internal view returns (bool) {
    return bytes(_getString(_key)).length == 0;
  }

  function _isZeroBytes(bytes32 _key) internal view returns (bool) {
    return _getBytes(_key).length == 0;
  }

  function _isZeroBool(bytes32 _key) internal view returns (bool) {
    return !_getBool(_key);
  }

  function _isZeroInt(bytes32 _key) internal view returns (bool) {
    return _getInt(_key) == 0;
  }

  function _isZeroBytes32(bytes32 _key) internal view returns (bool) {
    return _getBytes32(_key) == bytes32(0);
  }

  /// @dev Storage set methods
  function _setAddress(bytes32 _key, address _value) internal {
    _storage.setAddress(_key, _value);
  }

  function _setUint(bytes32 _key, uint256 _value) internal {
    _storage.setUint(_key, _value);
  }

  function _setString(bytes32 _key, string memory _value) internal {
    _storage.setString(_key, _value);
  }

  function _setBytes(bytes32 _key, bytes memory _value) internal {
    _storage.setBytes(_key, _value);
  }

  function _setBool(bytes32 _key, bool _value) internal {
    _storage.setBool(_key, _value);
  }

  function _setInt(bytes32 _key, int256 _value) internal {
    _storage.setInt(_key, _value);
  }

  function _setBytes32(bytes32 _key, bytes32 _value) internal {
    _storage.setBytes32(_key, _value);
  }

  /// @dev Storage delete methods
  function _deleteAddress(bytes32 _key) internal {
    _storage.deleteAddress(_key);
  }

  function _deleteUint(bytes32 _key) internal {
    _storage.deleteUint(_key);
  }

  function _deleteString(bytes32 _key) internal {
    _storage.deleteString(_key);
  }

  function _deleteBytes(bytes32 _key) internal {
    _storage.deleteBytes(_key);
  }

  function _deleteBool(bytes32 _key) internal {
    _storage.deleteBool(_key);
  }

  function _deleteInt(bytes32 _key) internal {
    _storage.deleteInt(_key);
  }

  function _deleteBytes32(bytes32 _key) internal {
    _storage.deleteBytes32(_key);
  }
}
