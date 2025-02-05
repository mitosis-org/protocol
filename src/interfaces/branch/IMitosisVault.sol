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

  event MatrixInitialized(address hubMatrixVault, address asset);
  event MatrixDepositedWithSupply(
    address indexed asset, address indexed to, address indexed hubMatrixVault, uint256 amount
  );
  event MatrixAllocated(address indexed hubMatrixVault, uint256 amount);
  event MatrixDeallocated(address indexed hubMatrixVault, uint256 amount);
  event MatrixFetched(address indexed hubMatrixVault, uint256 amount);
  event MatrixReturned(address indexed hubMatrixVault, uint256 amount);

  event MatrixYieldSettled(address indexed hubMatrixVault, uint256 amount);
  event MatrixLossSettled(address indexed hubMatrixVault, uint256 amount);
  event MatrixExtraRewardsSettled(address indexed hubMatrixVault, address indexed reward, uint256 amount);

  event MatrixHalted(address indexed hubMatrixVault, MatrixAction action);
  event MatrixResumed(address indexed hubMatrixVault, MatrixAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error MatrixDepositedWithSupply__MatrixNotInitialized(address hubMatrixVault);
  error MatrixDepositedWithSupply__MatrixAlreadyInitialized(address hubMatrixVault);

  error IMitosisVault__InvalidMatrixVault(address hubMatrixVault, address asset);

  //=========== NOTE: View functions ===========//

  function isMatrixInitialized(address hubMatrixVault) external view returns (bool);
  function availableMatrix(address hubMatrixVault) external view returns (uint256);

  //=========== NOTE: Asset ===========//

  function depositWithMatrixSupply(address asset, address to, address hubMatrixVault, uint256 amount) external;

  //=========== NOTE: Matrix ===========//

  function initializeMatrix(address hubMatrixVault, address asset) external;

  function allocateMatrix(address hubMatrixVault, uint256 amount) external;
  function deallocateMatrix(address hubMatrixVault, uint256 amount) external;

  function fetchMatrix(address hubMatrixVault, uint256 amount) external;
  function returnMatrix(address hubMatrixVault, uint256 amount) external;

  function settleMatrixYield(address hubMatrixVault, uint256 amount) external;
  function settleMatrixLoss(address hubMatrixVault, uint256 amount) external;
  function settleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount) external;
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
