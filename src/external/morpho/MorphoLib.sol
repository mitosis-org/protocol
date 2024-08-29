// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
import {Id, MarketParams, Market, IIrm, IMorpho} from './Morpho.sol';
import {MorphoStorageLib} from './MorphoStorageLib.sol';



uint256 constant WAD = 1e18;

/// @title MathLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library to manage fixed-point arithmetic.
library MathLib {
  /// @dev (x * y) / WAD rounded down.
  function wMulDown(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivDown(x, y, WAD);
  }

  /// @dev (x * WAD) / y rounded down.
  function wDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivDown(x, WAD, y);
  }

  /// @dev (x * WAD) / y rounded up.
  function wDivUp(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivUp(x, WAD, y);
  }

  /// @dev (x * y) / denominator rounded down.
  function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256) {
    return (x * y) / denominator;
  }

  /// @dev (x * y) / denominator rounded up.
  function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256) {
    return (x * y + (denominator - 1)) / denominator;
  }

  /// @dev The sum of the last three terms in a four term taylor series expansion
  ///      to approximate a continuous compound interest rate: e^(nx) - 1.
  function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256) {
    uint256 firstTerm = x * n;
    uint256 secondTerm = mulDivDown(firstTerm, firstTerm, 2 * WAD);
    uint256 thirdTerm = mulDivDown(secondTerm, firstTerm, 3 * WAD);

    return firstTerm + secondTerm + thirdTerm;
  }
}

/// @title SharesMathLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Shares management library.
/// @dev This implementation mitigates share price manipulations, using OpenZeppelin's method of virtual shares:
/// https://docs.openzeppelin.com/contracts/4.x/erc4626#inflation-attack.
library SharesMathLib {
  using MathLib for uint256;

  /// @dev The number of virtual shares has been chosen low enough to prevent overflows, and high enough to ensure
  /// high precision computations.
  uint256 internal constant VIRTUAL_SHARES = 1e6;

  /// @dev A number of virtual assets of 1 enforces a conversion rate between shares and assets when a market is
  /// empty.
  uint256 internal constant VIRTUAL_ASSETS = 1;

  /// @dev Calculates the value of `assets` quoted in shares, rounding down.
  function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
    return assets.mulDivDown(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  /// @dev Calculates the value of `shares` quoted in assets, rounding down.
  function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
    return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }

  /// @dev Calculates the value of `assets` quoted in shares, rounding up.
  function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
    return assets.mulDivUp(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
  }

  /// @dev Calculates the value of `shares` quoted in assets, rounding up.
  function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
    return shares.mulDivUp(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }
}

/// @title MarketParamsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library to convert a market to its id.
library MarketParamsLib {
  /// @notice Returns the id of the market `marketParams`.
  function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId) {
    assembly ('memory-safe') {
      marketParamsId := keccak256(marketParams, mul(5, 32))
    }
  }
}

/// @title MorphoLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Helper library to access Morpho storage variables.
/// @dev Warning: Supply and borrow getters may return outdated values that do not include accrued interest.
library MorphoLib {
  function supplyShares(IMorpho morpho, Id id, address user) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.positionSupplySharesSlot(id, user));
    return uint256(morpho.extSloads(slot)[0]);
  }

  function borrowShares(IMorpho morpho, Id id, address user) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
    return uint128(uint256(morpho.extSloads(slot)[0]));
  }

  function collateral(IMorpho morpho, Id id, address user) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
    return uint256(morpho.extSloads(slot)[0] >> 128);
  }

  function totalSupplyAssets(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
    return uint128(uint256(morpho.extSloads(slot)[0]));
  }

  function totalSupplyShares(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
    return uint256(morpho.extSloads(slot)[0] >> 128);
  }

  function totalBorrowAssets(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
    return uint128(uint256(morpho.extSloads(slot)[0]));
  }

  function totalBorrowShares(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
    return uint256(morpho.extSloads(slot)[0] >> 128);
  }

  function lastUpdate(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketLastUpdateAndFeeSlot(id));
    return uint128(uint256(morpho.extSloads(slot)[0]));
  }

  function fee(IMorpho morpho, Id id) internal view returns (uint256) {
    bytes32[] memory slot = _array(MorphoStorageLib.marketLastUpdateAndFeeSlot(id));
    return uint256(morpho.extSloads(slot)[0] >> 128);
  }

  function _array(bytes32 x) private pure returns (bytes32[] memory) {
    bytes32[] memory res = new bytes32[](1);
    res[0] = x;
    return res;
  }
}

/// @title MorphoBalancesLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Helper library exposing getters with the expected value after interest accrual.
/// @dev This library is not used in Morpho itself and is intended to be used by integrators.
/// @dev The getter to retrieve the expected total borrow shares is not exposed because interest accrual does not apply
/// to it. The value can be queried directly on Morpho using `totalBorrowShares`.
library MorphoBalancesLib {
  using MathLib for uint256;
  using MathLib for uint128;
  using MorphoLib for IMorpho;
  using SharesMathLib for uint256;
  using MarketParamsLib for MarketParams;

  /// @notice Thrown when the maximum uint128 is exceeded.
  string internal constant MAX_UINT128_EXCEEDED = 'max uint128 exceeded';

  /// @dev Returns `x` safely cast to uint128.
  function toUint128(uint256 x) internal pure returns (uint128) {
    require(x <= type(uint128).max, MAX_UINT128_EXCEEDED);
    return uint128(x);
  }

  function expectedMarketBalances(
    IMorpho morpho,
    MarketParams memory marketParams
  ) internal view returns (uint256, uint256, uint256, uint256) {
    Id id = marketParams.id();

    Market memory market = morpho.market(id);

    uint256 elapsed = block.timestamp - market.lastUpdate;

    if (elapsed != 0 && market.totalBorrowAssets != 0) {
      uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
      uint256 interest = market.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
      market.totalBorrowAssets += toUint128(interest);
      market.totalSupplyAssets += toUint128(interest);

      if (market.fee != 0) {
        uint256 feeAmount = interest.wMulDown(market.fee);
        // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
        // that total supply is already updated.
        uint256 feeShares = feeAmount.toSharesDown(market.totalSupplyAssets - feeAmount, market.totalSupplyShares);
        market.totalSupplyShares += toUint128(feeShares);
      }
    }

    return (market.totalSupplyAssets, market.totalSupplyShares, market.totalBorrowAssets, market.totalBorrowShares);
  }

  /// @dev Warning: Wrong for `feeRecipient` because their supply shares increase is not taken into account.
  function expectedSupplyBalance(
    IMorpho morpho,
    MarketParams memory marketParams,
    address user
  ) internal view returns (uint256) {
    Id id = marketParams.id();
    uint256 supplyShares = morpho.supplyShares(id, user);
    (uint256 totalSupplyAssets, uint256 totalSupplyShares, , ) = expectedMarketBalances(morpho, marketParams);

    return supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
  }
}
