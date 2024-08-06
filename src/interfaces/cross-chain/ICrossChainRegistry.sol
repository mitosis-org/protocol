// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MsgType } from '../../cross-chain/messages/Message.sol';

interface ICrossChainRegistry {
  /// @dev Returns all of the registered ChainIDs.
  function getChains() external view returns (uint256[] memory);

  /// @dev Returns the chain name of the ChainID.
  function getChainName(uint256 chain) external view returns (string memory);

  /// @dev Returns the Hyperlane domain by ChainID.
  function getHyperlaneDomain(uint256 chain) external view returns (uint32);

  /**
   * @dev Returns the Hyperlane destination address by ChainID, MsgType.
   *
   * This K/V storage allows routing to multiple contracts depending on
   * the message type. (Variable added because Hyperlane.Router can only
   * enroll one address in one domain by default). This variable was used
   * in the initial PoC and is currently deprecated; if it becomes clear
   * that this will not be the case in the future, this variable should
   * be removed.
   */
  function getHyperlaneRoute(uint32 hplDomain, MsgType msgType) external view returns (address);

  /// @dev Returns the Other chain's MitosisVault address by ChainID, Asset on Mitosis address.
  function getVault(uint256 chain, address asset) external view returns (address);

  /// @dev Returns the Asset on Mitosis address by ChainId, Other chain's MitosisVault address.
  function getVaultUnderlyingAsset(uint256 chain, address vault) external view returns (address);

  /// @dev Returns the ChainID by Hyperlane domain.
  function getChainByHyperlaneDomain(uint32 hplDomain) external view returns (uint256);

  /// @dev Sets the chain information including ChainID, name, and Hyperlane domain.
  function setChain(uint256 chain, string calldata name, uint32 hplDomain) external;

  /// @dev Sets the vault address and its underlying asset for a specific ChainID.
  function setVault(uint256 chain, address vault, address underlyingAsset) external;

  /// @dev Sets the Hyperlane route for a specific ChainID and message type to a target address.
  function setHyperlaneRoute(uint32 hplDomain, MsgType msgType, address target) external;
}
