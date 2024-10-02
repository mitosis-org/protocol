// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @dev Struct to store protocol information
 * @param protocolId Unique identifier for the protocol
 * @param eolAsset Address of the EOL asset associated with the protocol
 * @param chainId ID of the chain where the protocol is deployed
 * @param name Name of the protocol
 * @param metadata Additional metadata about the protocol
 * @param registeredAt Timestamp when the protocol was registered
 */
struct ProtocolInfo {
  uint256 protocolId;
  address eolAsset;
  uint256 chainId;
  string name;
  string metadata;
  uint48 registeredAt;
}

/**
 * @title IEOLProtocolRegistry
 * @author Manythings Pte. Ltd.
 * @dev Interface for the EOL Protocol Registry, which manages the registration of EOL protocols.
 */
interface IEOLProtocolRegistry {
  /**
   * @notice Emitted when a new protocol is registered
   * @param protocolId Unique identifier of the registered protocol
   * @param eolAsset Address of the EOL asset associated with the protocol
   * @param chainId ID of the chain where the protocol is deployed
   * @param name Name of the protocol
   * @param metadata Additional metadata about the protocol
   */
  event ProtocolRegistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name, string metadata
  );

  /**
   * @notice Emitted when a protocol is unregistered
   * @param protocolId Unique identifier of the unregistered protocol
   * @param eolAsset Address of the EOL asset associated with the protocol
   * @param chainId ID of the chain where the protocol was deployed
   * @param name Name of the protocol
   */
  event ProtocolUnregistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name
  );

  /**
   * @notice Emitted when an account is authorized for an EOL asset
   * @param eolAsset Address of the EOL asset
   * @param account Address of the authorized account
   */
  event Authorized(address indexed eolAsset, address indexed account);

  /**
   * @notice Emitted when an account is unauthorized for an EOL asset
   * @param eolAsset Address of the EOL asset
   * @param account Address of the unauthorized account
   */
  event Unauthorized(address indexed eolAsset, address indexed account);

  /**
   * @notice Error thrown when attempting to register an already registered protocol
   * @param protocolId Unique identifier of the protocol
   * @param eolAsset Address of the EOL asset
   * @param chainId ID of the chain
   * @param name Name of the protocol
   */
  error IEOLProtocolRegistry__AlreadyRegistered(uint256 protocolId, address eolAsset, uint256 chainId, string name);

  /**
   * @notice Error thrown when attempting to unregister a non-registered protocol
   * @param protocolId Unique identifier of the protocol
   */
  error IEOLProtocolRegistry__NotRegistered(uint256 protocolId);

  /**
   * @notice Returns an array of protocol IDs for a given EOL asset and chain
   * @param eolAsset Address of the EOL asset
   * @param chainId ID of the chain
   * @return An array of protocol IDs
   */
  function protocolIds(address eolAsset, uint256 chainId) external view returns (uint256[] memory);

  /**
   * @notice Calculates the protocol ID based on EOL asset, chain ID, and name
   * @param eolAsset Address of the EOL asset
   * @param chainId ID of the chain
   * @param name Name of the protocol
   * @return The calculated protocol ID
   */
  function protocolId(address eolAsset, uint256 chainId, string memory name) external pure returns (uint256);

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

  /**
   * @notice Checks if a protocol is registered using its details
   * @param eolAsset Address of the EOL asset
   * @param chainId ID of the chain
   * @param name Name of the protocol
   * @return Boolean indicating whether the protocol is registered
   */
  function isProtocolRegistered(address eolAsset, uint256 chainId, string memory name) external view returns (bool);

  /**
   * @notice Registers a new protocol
   * @param eolAsset Address of the EOL asset
   * @param chainId ID of the chain
   * @param name Name of the protocol
   * @param metadata Additional metadata about the protocol
   */
  function registerProtocol(address eolAsset, uint256 chainId, string memory name, string memory metadata) external;

  /**
   * @notice Unregisters a protocol
   * @param protocolId_ Unique identifier of the protocol to unregister
   */
  function unregisterProtocol(uint256 protocolId_) external;
}
