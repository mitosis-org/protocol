// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMitosisVault } from './IMitosisVault.sol';

interface IMitosisVaultEntrypoint {
  function vault() external view returns (IMitosisVault);

  function mitosisDomain() external view returns (uint32);

  function mitosisAddr() external view returns (bytes32);

  function deposit(address asset, address to, uint256 amount) external;

  function depositWithMatrixSupply(address asset, address to, address hubMatrixBasketAsset, uint256 amount) external;

  function deallocateMatrixLiquidity(address hubMatrixBasketAsset, uint256 amount) external;

  function settleMatrixYield(address hubMatrixBasketAsset, uint256 amount) external;

  function settleMatrixLoss(address hubMatrixBasketAsset, uint256 amount) external;

  function settleMatrixExtraRewards(address hubMatrixBasketAsset, address reward, uint256 amount) external;
}
