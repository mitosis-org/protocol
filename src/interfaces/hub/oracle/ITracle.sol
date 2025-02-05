// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library TracleConstants {
  uint8 internal constant PRICE_DECIMALS = 8;
}

/**
 * @title ITracle
 * @notice An interface for a temporary oracle contract only for testnet.
 */
interface ITracle {
  struct Price {
    uint208 price;
    uint48 updatedAt;
  }

  struct MatrixVaultPriceConfig {
    address matrixVault;
    bytes32 underlyingPriceId;
  }

  event PriceUpdated(bytes32 indexed id, uint208 price, uint48 updatedAt);
  event MatrixVaultPriceConfigSet(bytes32 indexed id, address matrixVault, bytes32 underlyingPriceId);
  event MatrixVaultPriceConfigUnset(bytes32 indexed id);

  error ITracle__InvalidPriceId(bytes32 id);

  function getPrice(bytes32 id) external view returns (Price memory);
}
