// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IMitosisVaultEntrypoint {
  function deposit(address asset, address to, uint256 amount) external;

  function deallocateEOL(uint256 eolId, uint256 amount) external;

  function settleYield(uint256 eolId, uint256 amount) external;

  function settleLoss(uint256 eolId, uint256 amount) external;

  function settleExtraRewards(uint256 eolId, address reward, uint256 amount) external;
}
