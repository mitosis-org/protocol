// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @dev Struct to store protocol information
 * @param protocolId Unique identifier for the protocol
 * @param eolVault Address of the EOLVault associated with the protocol
 * @param chainId ID of the chain where the protocol is deployed
 * @param name Name of the protocol
 * @param branchStrategy Address of the Strategy on branch chain
 * @param metadata Additional metadata about the protocol
 * @param registeredAt Timestamp when the protocol was registered
 */
struct ProtocolInfo {
  uint256 protocolId;
  address eolVault;
  uint256 chainId;
  string name;
  address branchStrategy;
  string metadata;
  uint48 registeredAt;
}

/**
 * @title IEOLProtocolRegistry
 * @dev Interface for the EOL Protocol Registry, which manages the registration of EOL protocols.
 */
interface IEOLProtocolRegistry {
  /**
   * @notice Emitted when a new protocol is registered
   * @param protocolId Unique identifier of the registered protocol
   * @param eolVault Address of the EOLVault associated with the protocol
   * @param chainId ID of the chain where the protocol is deployed
   * @param name Name of the protocol
   * @param branchStrategy Address of the Strategy on branch chain
   * @param metadata Additional metadata about the protocol
   */
  event ProtocolRegistered(
    uint256 indexed protocolId,
    address indexed eolVault,
    uint256 indexed chainId,
    string name,
    address branchStrategy,
    string metadata
  );

  /**
   * @notice Emitted when a protocol is unregistered
   * @param protocolId Unique identifier of the unregistered protocol
   * @param eolVault Address of the EOLVault associated with the protocol
   * @param chainId ID of the chain where the protocol was deployed
   * @param name Name of the protocol
   */
  event ProtocolUnregistered(
    uint256 indexed protocolId, address indexed eolVault, uint256 indexed chainId, string name
  );

  event Authorized(address indexed eolVault, address indexed account);
  event Unauthorized(address indexed eolVault, address indexed account);

  error IEOLProtocolRegistry__AlreadyRegistered(uint256 protocolId, address eolVault, uint256 chainId, string name);
  error IEOLProtocolRegistry__NotRegistered(uint256 protocolId);

  function protocolIds(address eolVault, uint256 chainId) external view returns (uint256[] memory);

  function protocolId(address eolVault, uint256 chainId, string memory name) external pure returns (uint256);

  /**
   * @notice Retrieves the protocol information for a given protocol ID
   * @param protocolId_ Unique identifier of the protocol
   * @return ProtocolInfo struct containing the protocol information
   */
  function protocol(uint256 protocolId_) external view returns (ProtocolInfo memory);

  /**
   * @notice Checks if a protocol is registered using its ID
   * @param protocolId_ Unique identifier of the protocol
   * @return Boolean indicating whether the protocol is registered
   */
  function isProtocolRegistered(uint256 protocolId_) external view returns (bool);

  function isProtocolRegistered(address eolVault, uint256 chainId, string memory name) external view returns (bool);

  function registerProtocol(
    address eolVault,
    uint256 chainId,
    string memory name,
    address branchStrategy,
    string memory metadata
  ) external;

  /**
   * @notice Unregisters a protocol
   * @param protocolId_ Unique identifier of the protocol to unregister
   */
  function unregisterProtocol(uint256 protocolId_) external;
}
