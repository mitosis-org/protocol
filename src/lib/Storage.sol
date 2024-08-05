// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Storage {
  mapping(bytes32 => string) private stringStorage;
  mapping(bytes32 => bytes) private bytesStorage;
  mapping(bytes32 => uint256) private uintStorage;
  mapping(bytes32 => int256) private intStorage;
  mapping(bytes32 => address) private addressStorage;
  mapping(bytes32 => bool) private booleanStorage;
  mapping(bytes32 => bytes32) private bytes32Storage;

  function getAddress(bytes32 _key) external view returns (address r) {
    return addressStorage[_key];
  }

  /// @param _key The key for the record
  function getUint(bytes32 _key) external view returns (uint256 r) {
    return uintStorage[_key];
  }

  /// @param _key The key for the record
  function getString(bytes32 _key) external view returns (string memory) {
    return stringStorage[_key];
  }

  /// @param _key The key for the record
  function getBytes(bytes32 _key) external view returns (bytes memory) {
    return bytesStorage[_key];
  }

  /// @param _key The key for the record
  function getBool(bytes32 _key) external view returns (bool r) {
    return booleanStorage[_key];
  }

  /// @param _key The key for the record
  function getInt(bytes32 _key) external view returns (int256 r) {
    return intStorage[_key];
  }

  /// @param _key The key for the record
  function getBytes32(bytes32 _key) external view returns (bytes32 r) {
    return bytes32Storage[_key];
  }

  /// @param _key The key for the record
  function setAddress(bytes32 _key, address _value) external {
    addressStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setUint(bytes32 _key, uint256 _value) external {
    uintStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setString(bytes32 _key, string calldata _value) external {
    stringStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBytes(bytes32 _key, bytes calldata _value) external {
    bytesStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBool(bytes32 _key, bool _value) external {
    booleanStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setInt(bytes32 _key, int256 _value) external {
    intStorage[_key] = _value;
  }

  /// @param _key The key for the record
  function setBytes32(bytes32 _key, bytes32 _value) external {
    bytes32Storage[_key] = _value;
  }

  /// @param _key The key for the record
  function deleteAddress(bytes32 _key) external {
    delete addressStorage[_key];
  }

  /// @param _key The key for the record
  function deleteUint(bytes32 _key) external {
    delete uintStorage[_key];
  }

  /// @param _key The key for the record
  function deleteString(bytes32 _key) external {
    delete stringStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBytes(bytes32 _key) external {
    delete bytesStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBool(bytes32 _key) external {
    delete booleanStorage[_key];
  }

  /// @param _key The key for the record
  function deleteInt(bytes32 _key) external {
    delete intStorage[_key];
  }

  /// @param _key The key for the record
  function deleteBytes32(bytes32 _key) external {
    delete bytes32Storage[_key];
  }
}
