// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IMitosisVaultEntrypoint {
  function deposit(address asset, address to, uint256 amount) external;

  function deallocateEOL(address hubEOLVault, uint256 amount) external;

  function settleYield(address hubEOLVault, uint256 amount) external;

  function settleLoss(address hubEOLVault, uint256 amount) external;

  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external;
}
