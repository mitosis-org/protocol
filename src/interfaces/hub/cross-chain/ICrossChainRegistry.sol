// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICrossChainRegistry {
  error ICrossChainRegistry__NotRegistered();
  error ICrossChainRegistry__AlreadyRegistered();
  error ICrossChainRegistry__NotEnrolled();
  error ICrossChainRegistry__AlreadyEnrolled();

  /// @dev Returns all of the registered ChainIDs.
  function getChainIds() external view returns (uint256[] memory);

  /// @dev Returns the chain name of the ChainID.
  function getChainName(uint256 chainId) external view returns (string memory);

  /// @dev Returns the Hyperlane domain by ChainID.
  function getHyperlaneDomain(uint256 chainId) external view returns (uint32);

  /// @dev Returns the Other chain's MitosisVault address by ChainID.
  function getVault(uint256 chainId) external view returns (address);

  function getEntrypoint(uint256 chainId) external view returns (address);

  function entrypointEnrolled(uint256 chainId) external view returns (bool);

  /// @dev Returns the ChainID by Hyperlane domain.
  function getChainIdByHyperlaneDomain(uint32 hplDomain) external view returns (uint256);

  function isRegisteredChain(uint256 chainId) external view returns (bool);

  /// @dev Sets the chain information including ChainID, name, and Hyperlane domain.
  function setChain(uint256 chainId, string calldata name, uint32 hplDomain, address entrypoint) external;

  /// @dev Sets the vault address for a specific ChainID.
  function setVault(uint256 chainId, address vault) external;

  function enrollEntrypoint(address hplRouter) external;

  function enrollEntrypoint(address hplRouter, uint256 chainId) external;
}
