// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

enum VLFAction {
  None,
  FetchVLF
}

interface IMitosisVaultVLF {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event VLFInitialized(address hubVLF, address asset);
  event VLFDepositedWithSupply(
    address indexed asset, address indexed to, address indexed hubVLF, uint256 amount
  );
  event VLFAllocated(address indexed hubVLF, uint256 amount);
  event VLFDeallocated(address indexed hubVLF, uint256 amount);
  event VLFFetched(address indexed hubVLF, uint256 amount);
  event VLFReturned(address indexed hubVLF, uint256 amount);

  event VLFYieldSettled(address indexed hubVLF, uint256 amount);
  event VLFLossSettled(address indexed hubVLF, uint256 amount);
  event VLFExtraRewardsSettled(address indexed hubVLF, address indexed reward, uint256 amount);

  event VLFHalted(address indexed hubVLF, VLFAction action);
  event VLFResumed(address indexed hubVLF, VLFAction action);

  event VLFStrategyExecutorSet(address indexed hubVLF, address indexed strategyExecutor);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IMitosisVaultVLF__VLFNotInitialized(address hubVLF);
  error IMitosisVaultVLF__VLFAlreadyInitialized(address hubVLF);
  error IMitosisVaultVLF__InvalidVLF(address hubVLF, address asset);
  error IMitosisVaultVLF__StrategyExecutorNotDrained(address hubVLF, address strategyExecutor);

  //=========== NOTE: View functions ===========//

  function isVLFInitialized(address hubVLF) external view returns (bool);
  function availableVLF(address hubVLF) external view returns (uint256);
  function vlfStrategyExecutor(address hubVLF) external view returns (address);

  //=========== NOTE: QUOTE FUNCTIONS ===========//

  function quoteDepositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount)
    external
    view
    returns (uint256);

  function quoteDeallocateVLF(address hubVLF, uint256 amount) external view returns (uint256);
  function quoteSettleVLFYield(address hubVLF, uint256 amount) external view returns (uint256);
  function quoteSettleVLFLoss(address hubVLF, uint256 amount) external view returns (uint256);
  function quoteSettleVLFExtraRewards(address hubVLF, address reward, uint256 amount)
    external
    view
    returns (uint256);

  //=========== NOTE: Asset ===========//

  function depositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount) external payable;

  //=========== NOTE: VLF ===========//

  function initializeVLF(address hubVLF, address asset) external;

  function allocateVLF(address hubVLF, uint256 amount) external payable;
  function deallocateVLF(address hubVLF, uint256 amount) external payable;

  function fetchVLF(address hubVLF, uint256 amount) external;
  function returnVLF(address hubVLF, uint256 amount) external;

  function settleVLFYield(address hubVLF, uint256 amount) external payable;
  function settleVLFLoss(address hubVLF, uint256 amount) external payable;
  function settleVLFExtraRewards(address hubVLF, address reward, uint256 amount) external payable;

  //=========== NOTE: Ownable ===========//

  function setVLFStrategyExecutor(address hubVLF, address strategyExecutor) external;
}
