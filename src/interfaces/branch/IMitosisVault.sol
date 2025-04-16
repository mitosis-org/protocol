// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

enum AssetAction {
  Deposit
}

enum EOLAction {
  FetchEOL
}

interface IMitosisVault {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event AssetInitialized(address asset);

  event Deposited(address indexed asset, address indexed to, uint256 amount);
  event DepositedWithOptIn(address indexed asset, address indexed to, address indexed eolVault, uint256 amount);
  event Redeemed(address indexed asset, address indexed to, uint256 amount);

  event EOLInitialized(address hubEOLVault, address asset);

  event EOLAllocated(address indexed hubEOLVault, uint256 amount);
  event EOLDeallocated(address indexed hubEOLVault, uint256 amount);
  event EOLFetched(address indexed hubEOLVault, uint256 amount);
  event EOLReturned(address indexed hubEOLVault, uint256 amount);

  event YieldSettled(address indexed hubEOLVault, uint256 amount);
  event LossSettled(address indexed hubEOLVault, uint256 amount);
  event ExtraRewardsSettled(address indexed hubEOLVault, address indexed reward, uint256 amount);

  event EntrypointSet(address entrypoint);
  event EOLStrategyExecutorSet(address indexed hubEOLVault, address indexed eolStrategyExecutor);

  event AssetHalted(address indexed asset, AssetAction action);
  event AssetResumed(address indexed asset, AssetAction action);

  event EOLHalted(address indexed hubEOLVault, EOLAction action);
  event EOLResumed(address indexed hubEOLVault, EOLAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IMitosisVault__AssetNotInitialized(address asset);
  error IMitosisVault__AssetAlreadyInitialized(address asset);

  error IMitosisVault__EOLNotInitialized(address hubEOLVault);
  error IMitosisVault__EOLAlreadyInitialized(address hubEOLVault);

  error IMitosisVault__InvalidEOLVault(address hubEOLVault, address asset);

  error IMitosisVault__EOLStrategyExecutorNotDrained(address hubEOLVault, address eolStrategyExecutor);

  //=========== NOTE: View functions ===========//

  function isAssetInitialized(address asset) external view returns (bool);
  function isEOLInitialized(address hubEOLVault) external view returns (bool);
  function availableEOL(address hubEOLVault) external view returns (uint256);
  function entrypoint() external view returns (address);
  function eolStrategyExecutor(address hubEOLVault) external view returns (address);

  //=========== NOTE: Asset ===========//

  function initializeAsset(address asset) external;

  function deposit(address asset, address to, uint256 amount) external;
  function depositWithOptIn(address asset, address to, address hubEOLVault, uint256 amount) external;
  function redeem(address asset, address to, uint256 amount) external;

  //=========== NOTE: EOL ===========//

  function initializeEOL(address hubEOLVault, address asset) external;

  function allocateEOL(address hubEOLVault, uint256 amount) external;
  function deallocateEOL(address hubEOLVault, uint256 amount) external;

  function fetchEOL(address hubEOLVault, uint256 amount) external;
  function returnEOL(address hubEOLVault, uint256 amount) external;

  function settleYield(address hubEOLVault, uint256 amount) external;
  function settleLoss(address hubEOLVault, uint256 amount) external;
  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external;

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEntrypoint(address entrypoint) external;
  function setEOLStrategyExecutor(address hubEOLVault, address eolStrategyExecutor) external;
}
