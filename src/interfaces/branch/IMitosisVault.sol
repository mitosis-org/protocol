// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

enum AssetAction {
  Deposit
}

enum MatrixAction {
  FetchMatrix
}

interface IMatrixMitosisVault {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event MatrixInitialized(address hubMatrixBasketAsset, address asset);
  event MatrixDepositedWithSupply(
    address indexed asset, address indexed to, address indexed hubMatrixBasketAsset, uint256 amount
  );
  event MatrixLiquidityAllocated(address indexed hubMatrixBasketAsset, uint256 amount);
  event MatrixLiquidityDeallocated(address indexed hubMatrixBasketAsset, uint256 amount);
  event MatrixLiquidityFetched(address indexed hubMatrixBasketAsset, uint256 amount);
  event MatrixLiquidityReturned(address indexed hubMatrixBasketAsset, uint256 amount);

  event MatrixYieldSettled(address indexed hubMatrixBasketAsset, uint256 amount);
  event MatrixLossSettled(address indexed hubMatrixBasketAsset, uint256 amount);
  event MatrixExtraRewardsSettled(address indexed hubMatrixBasketAsset, address indexed reward, uint256 amount);

  event MatrixHalted(address indexed hubMatrixBasketAsset, MatrixAction action);
  event MatrixResumed(address indexed hubMatrixBasketAsset, MatrixAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error MatrixDepositedWithSupply__MatrixNotInitialized(address hubMatrixBasketAsset);
  error MatrixDepositedWithSupply__MatrixAlreadyInitialized(address hubMatrixBasketAsset);

  error IMitosisVault__InvalidMatrixVault(address hubMatrixBasketAsset, address asset);

  //=========== NOTE: View functions ===========//

  function isMatrixInitialized(address hubMatrixBasketAsset) external view returns (bool);
  function availableMatrixLiquidity(address hubMatrixBasketAsset) external view returns (uint256);

  //=========== NOTE: Asset ===========//

  function depositWithMatrixSupply(address asset, address to, address hubMatrixBasketAsset, uint256 amount) external;

  //=========== NOTE: Matrix ===========//

  function initializeMatrix(address hubMatrixBasketAsset, address asset) external;

  function allocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external;
  function deallocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external;

  function fetchMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external;
  function returnMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external;

  function settleMatrixYield(address hubMatrixBasketAsset, uint256 amount) external;
  function settleMatrixLoss(address hubMatrixBasketAsset, uint256 amount) external;
  function settleMatrixExtraRewards(address hubMatrixBasketAsset, address reward, uint256 amount) external;
}

interface IMitosisVault is IMatrixMitosisVault {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(address asset);

  event Deposited(address indexed asset, address indexed to, uint256 amount);
  event Redeemed(address indexed asset, address indexed to, uint256 amount);

  event EntrypointSet(address entrypoint);
  event MatrixStrategyExecutorSet(address indexed vault, address indexed strategyExecutor);

  event AssetHalted(address indexed asset, AssetAction action);
  event AssetResumed(address indexed asset, AssetAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IMitosisVault__AssetNotInitialized(address asset);
  error IMitosisVault__AssetAlreadyInitialized(address asset);
  error IMitosisVault__StrategyExecutorNotDrained(address vault, address strategyExecutor);

  //=========== NOTE: View functions ===========//

  function isAssetInitialized(address asset) external view returns (bool);
  function entrypoint() external view returns (address);
  function matrixStrategyExecutor(address vault) external view returns (address);

  //=========== NOTE: Asset ===========//

  function initializeAsset(address asset) external;
  function deposit(address asset, address to, uint256 amount) external;
  function redeem(address asset, address to, uint256 amount) external;

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(address entrypoint) external;
  function setMatrixStrategyExecutor(address vault, address strategyExecutor) external;
}
