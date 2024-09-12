// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

enum AssetAction {
  Deposit
}

enum EOLAction {
  FetchEOL
}

interface IMitosisVault {
  //=========== NOTE: Asset ===========//

  function initializeAsset(address asset) external;

  function deposit(address asset, address to, uint256 amount) external;
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
}
