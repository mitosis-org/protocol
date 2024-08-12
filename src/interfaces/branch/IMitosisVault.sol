// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

enum Action {
  Deposit,
  FetchEOL
}

interface IMitosisVault {
  function initializeAsset(address asset, bool enableDeposit) external;
  function deposit(address asset, address to, uint256 amount) external;
  function redeem(address asset, address to, uint256 amount) external;

  function allocateEOL(address asset, uint256 amount) external;
  function deallocateEOL(address asset, uint256 amount) external;

  function fetchEOL(address asset, uint256 amount) external;
  function returnEOL(address asset, uint256 amount) external;

  function settleYield(address asset, uint256 amount) external;
  function settleLoss(address asset, uint256 amount) external;
  function settleExtraRewards(address asset, address reward, uint256 amount) external;
}
