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

interface IEOLProtocolRegistry {
  event ProtocolRegistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name, string metadata
  );
  event ProtocolUnregistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name
  );

  event Authorized(address indexed eolAsset, address indexed account);
  event Unauthorized(address indexed eolAsset, address indexed account);

  error EOLProtocolRegistry__AlreadyRegistered(uint256 protocolId, address eolAsset, uint256 chainId, string name);
  error EOLProtocolRegistry__NotRegistered(uint256 protocolId);

  function protocolIds(address eolAsset, uint256 chainId) external view returns (uint256[] memory);

  function protocolId(address eolAsset, uint256 chainId, string memory name) external pure returns (uint256);

  function protocol(uint256 protocolId_) external view returns (ProtocolInfo memory);

  function isProtocolRegistered(uint256 protocolId_) external view returns (bool);

  function isProtocolRegistered(address eolAsset, uint256 chainId, string memory name) external view returns (bool);

  function registerProtocol(address eolAsset, uint256 chainId, string memory name, string memory metadata) external;

  function unregisterProtocol(uint256 protocolId_) external;
}
