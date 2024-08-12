// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisVaultEntrypoint {
  function deposit(address asset, address to, uint256 amount) external;

  function deallocateEOL(address asset, uint256 amount) external;

  function settleYield(address asset, uint256 amount) external;

  function settleLoss(address asset, uint256 amount) external;

  function settleExtraRewards(address asset, address reward, uint256 amount) external;
}
