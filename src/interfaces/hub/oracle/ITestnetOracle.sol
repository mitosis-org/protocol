// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library TestnetOracleConstants {
  uint8 internal constant PRICE_DECIMALS = 8;
}

interface ITestnetOracle {
  struct Price {
    uint208 price;
    uint48 updatedAt;
  }

  struct EOLVaultPriceConfig {
    address eolVault;
    bytes32 underlyingPriceId;
  }

  event PriceUpdated(bytes32 indexed id, uint208 price, uint48 updatedAt);
  event EOLVaultPriceConfigSet(bytes32 indexed id, address eolVault, bytes32 underlyingPriceId);
  event EOLVaultPriceConfigUnset(bytes32 indexed id);

  error ITestnetOracle__InvalidPriceId(bytes32 id);

  function getPrice(bytes32 id) external view returns (Price memory);
}
