// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MsgType } from '../../../hub/cross-chain/messages/Message.sol';

interface ICrossChainRegistry {
  /// @dev Returns all of the registered ChainIDs.
  function getChainIds() external view returns (uint256[] memory);

  /// @dev Returns the chain name of the ChainID.
  function getChainName(uint256 chainId) external view returns (string memory);

  /// @dev Returns the Hyperlane domain by ChainID.
  function getHyperlaneDomain(uint256 chainId) external view returns (uint32);

  /// @dev Returns the Other chain's MitosisVault address by ChainID, Asset on Mitosis address.
  function getVault(uint256 chainId, address asset) external view returns (address);

  /// @dev Returns the Asset on Mitosis address by ChainId, Other chain's MitosisVault address.
  function getVaultUnderlyingAsset(uint256 chainId, address vault) external view returns (address);

  /// @dev Returns the ChainID by Hyperlane domain.
  function getChainIdByHyperlaneDomain(uint32 hplDomain) external view returns (uint256);

  /// @dev Sets the chain information including ChainID, name, and Hyperlane domain.
  function setChain(uint256 chainId, string calldata name, uint32 hplDomain) external;

  /// @dev Sets the vault address and its underlying asset for a specific ChainID.
  function setVault(uint256 chainId, address vault, address underlyingAsset) external;
}
