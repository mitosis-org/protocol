// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ICrossChainRegistry
 * @dev Interface for the Cross-Chain Registry, which manages chain and vault information across different networks.
 */
interface ICrossChainRegistry {
  /**
   * @notice Emitted when a new chain is registered or updated.
   * @param chainId The ID of the chain being set.
   * @param hplDomain The Hyperlane domain associated with the chain.
   * @param entrypoint The address of the entrypoint contract for the chain.
   * @param name The name of the chain.
   */
  event ChainSet(uint256 indexed chainId, uint32 indexed hplDomain, address indexed entrypoint, string name);

  /**
   * @notice Emitted when a vault is set for a chain.
   * @param chainId The ID of the chain.
   * @param vault The address of the vault set for the chain.
   */
  event VaultSet(uint256 indexed chainId, address indexed vault);

  /**
   * @notice Error thrown when attempting to register an already registered chain or Hyperlane domain.
   */
  error ICrossChainRegistry__NotRegistered();

  /**
   * @notice Error thrown when attempting to register an already registered chain or Hyperlane domain.
   */
  error ICrossChainRegistry__AlreadyRegistered();

  /**
   * @notice Error thrown when attempting to perform an operation on a chain that is not enrolled.
   */
  error ICrossChainRegistry__NotEnrolled();

  /**
   * @notice Error thrown when attempting to enroll an already enrolled chain.
   */
  error ICrossChainRegistry__AlreadyEnrolled();

  /**
   * @notice Returns an array of all registered chain IDs.
   * @return An array of uint256 representing the chain IDs.
   */
  function chainIds() external view returns (uint256[] memory);

  /**
   * @notice Returns the name of a specified chain.
   * @param chainId The ID of the chain.
   * @return The name of the chain as a string.
   */
  function chainName(uint256 chainId) external view returns (string memory);

  /**
   * @notice Returns the Hyperlane domain associated with a specified chain.
   * @param chainId The ID of the chain.
   * @return The Hyperlane domain as a uint32.
   */
  function hyperlaneDomain(uint256 chainId) external view returns (uint32);

  /**
   * @notice Returns the vault address for a specified chain.
   * @param chainId The ID of the chain.
   * @return The address of the vault.
   */
  function vault(uint256 chainId) external view returns (address);

  /**
   * @notice Returns the entrypoint address for a specified chain.
   * @param chainId The ID of the chain.
   * @return The address of the entrypoint.
   */
  function entrypoint(uint256 chainId) external view returns (address);

  /**
   * @notice Checks if the entrypoint for a specified chain is enrolled.
   * @param chainId The ID of the chain.
   * @return A boolean indicating whether the entrypoint is enrolled.
   */
  function entrypointEnrolled(uint256 chainId) external view returns (bool);

  /**
   * @notice Returns the chain ID associated with a specified Hyperlane domain.
   * @param hplDomain The Hyperlane domain.
   * @return The chain ID as a uint256.
   */
  function chainId(uint32 hplDomain) external view returns (uint256);

  /**
   * @notice Checks if a specified chain is registered.
   * @param chainId The ID of the chain.
   * @return A boolean indicating whether the chain is registered.
   */
  function isRegisteredChain(uint256 chainId) external view returns (bool);

  /**
   * @notice Set the information for a chain
   * @param chainId_ The ID of the chain.
   * @param name The name of the chain.
   * @param hplDomain The Hyperlane domain associated with the chain.
   * @param entrypoint_ The address of the entrypoint contract for the chain.
   */
  function setChain(uint256 chainId_, string calldata name, uint32 hplDomain, address entrypoint_) external;

  /**
   * @notice Sets the vault for a specified chain.
   * @param chainId_ The ID of the chain.
   * @param vault_ The address of the vault to be set.
   */
  function setVault(uint256 chainId_, address vault_) external;

  /**
   * @notice Enrolls the entrypoint for all registered chains.
   * @param hplRouter The address of the Hyperlane router.
   */
  function enrollEntrypoint(address hplRouter) external;

  /**
   * @notice Enrolls the entrypoint for a specified chain.
   * @param hplRouter The address of the Hyperlane router.
   * @param chainId_ The ID of the chain.
   */
  function enrollEntrypoint(address hplRouter, uint256 chainId_) external;
}
