// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEOLSettlementManager {
  function settleYield(address eolVault, uint256 amount) external;
  function settleLoss(address eolVault, uint256 amount) external;
  function settleExtraReward(address eolVault, address reward, uint256 amount) external;
}
