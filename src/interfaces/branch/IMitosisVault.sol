// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

enum AssetAction {
  Deposit
}

enum EOLAction {
  FetchEOL
}

interface IMitosisVault {
  //=========== NOTE: Asset ===========//

  function initializeAsset(address asset, bool enableDeposit) external;

  function deposit(address asset, address to, uint256 amount) external;
  function redeem(address asset, address to, uint256 amount) external;

  //=========== NOTE: EOL ===========//

  function initializeEOL(uint256 eolId, address asset) external;

  function allocateEOL(uint256 eolId, uint256 amount) external;
  function deallocateEOL(uint256 eolId, uint256 amount) external;

  function fetchEOL(uint256 eolId, uint256 amount) external;
  function returnEOL(uint256 eolId, uint256 amount) external;

  function settleYield(uint256 eolId, uint256 amount) external;
  function settleLoss(uint256 eolId, uint256 amount) external;
  function settleExtraRewards(uint256 eolId, address reward, uint256 amount) external;
}
