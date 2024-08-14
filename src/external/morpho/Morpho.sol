// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

type Id is bytes32;

struct MarketParams {
  address loanToken;
  address collateralToken;
  address oracle;
  address irm;
  uint256 lltv;
}

/// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
/// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
/// @dev Warning: `totalSupplyShares` does not contain the additional shares accrued by `feeRecipient` since the last
/// interest accrual.
struct Market {
  uint128 totalSupplyAssets;
  uint128 totalSupplyShares;
  uint128 totalBorrowAssets;
  uint128 totalBorrowShares;
  uint128 lastUpdate;
  uint128 fee;
}

/// @title IIrm
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Interface that IRMs used by Morpho must implement.
interface IIrm {
  /// @notice Returns the borrow rate of the market `marketParams`.
  /// @param marketParams The MarketParams struct of the market.
  /// @param market The Market struct of the market.
  function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256);

  /// @notice Returns the borrow rate of the market `marketParams` without modifying any storage.
  /// @param marketParams The MarketParams struct of the market.
  /// @param market The Market struct of the market.
  function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256);
}

/// @dev This interface is used for factorizing IMorphoStaticTyping and IMorpho.
/// @dev Consider using the IMorpho interface instead of this one.
interface IMorphoBase {
  /// @notice Supplies `assets` or `shares` on behalf of `onBehalf`, optionally calling back the caller's
  /// `onMorphoSupply` function with the given `data`.
  /// @dev Either `assets` or `shares` should be zero. Most use cases should rely on `assets` as an input so the
  /// caller is guaranteed to have `assets` tokens pulled from their balance, but the possibility to mint a specific
  /// amount of shares is given for full compatibility and precision.
  /// @dev Supplying a large amount can revert for overflow.
  /// @dev Supplying an amount of shares may lead to supply more or fewer assets than expected due to slippage.
  /// Consider using the `assets` parameter to avoid this.
  /// @param marketParams The market to supply assets to.
  /// @param assets The amount of assets to supply.
  /// @param shares The amount of shares to mint.
  /// @param onBehalf The address that will own the increased supply position.
  /// @param data Arbitrary data to pass to the `onMorphoSupply` callback. Pass empty data if not needed.
  /// @return assetsSupplied The amount of assets supplied.
  /// @return sharesSupplied The amount of shares minted.
  function supply(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    bytes memory data
  ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);

  /// @notice Withdraws `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
  /// @dev Either `assets` or `shares` should be zero. To withdraw max, pass the `shares`'s balance of `onBehalf`.
  /// @dev `msg.sender` must be authorized to manage `onBehalf`'s positions.
  /// @dev Withdrawing an amount corresponding to more shares than supplied will revert for underflow.
  /// @dev It is advised to use the `shares` input when withdrawing the full position to avoid reverts due to
  /// conversion roundings between shares and assets.
  /// @param marketParams The market to withdraw assets from.
  /// @param assets The amount of assets to withdraw.
  /// @param shares The amount of shares to burn.
  /// @param onBehalf The address of the owner of the supply position.
  /// @param receiver The address that will receive the withdrawn assets.
  /// @return assetsWithdrawn The amount of assets withdrawn.
  /// @return sharesWithdrawn The amount of shares burned.
  function withdraw(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    address receiver
  ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);

  /// @notice Returns the data stored on the different `slots`.
  function extSloads(bytes32[] memory slots) external view returns (bytes32[] memory);
}

/// @title IMorpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @dev Use this interface for Morpho to have access to all the functions with the appropriate function signatures.
interface IMorpho is IMorphoBase {
  /// @notice The state of the market corresponding to `id`.
  /// @dev Warning: `m.totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `m.totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `m.totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last
  /// interest accrual.
  function market(Id id) external view returns (Market memory m);

  /// @notice The market params corresponding to `id`.
  /// @dev This mapping is not used in Morpho. It is there to enable reducing the cost associated to calldata on layer
  /// 2s by creating a wrapper contract with functions that take `id` as input instead of `marketParams`.
  function idToMarketParams(Id id) external view returns (MarketParams memory);
}
