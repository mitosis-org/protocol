// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct ProtocolInfo {
  uint256 protocolId;
  address eolAsset;
  uint256 chainId;
  string name;
  string metadata;
  uint48 registeredAt;
}

interface IEOLProtocolRegistryStorageV1 {
  function protocolIds(address eolAsset, uint256 chainId) external view returns (uint256[] memory);

  function protocolId(address eolAsset, uint256 chainId, string memory name) external pure returns (uint256);

  function protocol(uint256 protocolId_) external view returns (ProtocolInfo memory);

  function isProtocolRegistered(uint256 protocolId_) external view returns (bool);

  function isProtocolRegistered(address eolAsset, uint256 chainId, string memory name) external view returns (bool);

  function isAuthorized(address eolAsset, address account) external view returns (bool);
}

interface IEOLProtocolRegistry is IEOLProtocolRegistryStorageV1 {
  function registerProtocol(address eolAsset, uint256 chainId, string memory name, string memory metadata) external;

  function unregisterProtocol(uint256 protocolId_) external;

  function authorize(address eolAsset, address account) external;

  function unauthorize(address eolAsset, address account) external;
}
