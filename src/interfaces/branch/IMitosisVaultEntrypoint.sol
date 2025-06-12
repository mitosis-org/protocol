// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IMitosisVault } from './IMitosisVault.sol';

interface IMitosisVaultEntrypoint {
  function vault() external view returns (IMitosisVault);

  function mitosisDomain() external view returns (uint32);

  function mitosisAddr() external view returns (bytes32);

  //=========== NOTE: QUOTE FUNCTIONS ===========//

  function quoteDeposit(address asset, address to, uint256 amount) external view returns (uint256);

  function quoteDepositWithSupplyMatrix(address asset, address to, address hubMatrixVault, uint256 amount)
    external
    view
    returns (uint256);

  function quoteDepositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount)
    external
    view
    returns (uint256);

  function quoteDeallocateMatrix(address hubMatrixVault, uint256 amount) external view returns (uint256);

  function quoteSettleMatrixYield(address hubMatrixVault, uint256 amount) external view returns (uint256);

  function quoteSettleMatrixLoss(address hubMatrixVault, uint256 amount) external view returns (uint256);

  function quoteSettleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount)
    external
    view
    returns (uint256);

  //=========== NOTE: MUTATIVE FUNCTIONS ===========//

  function deposit(address asset, address to, uint256 amount) external payable;

  function depositWithSupplyMatrix(address asset, address to, address hubMatrixVault, uint256 amount) external payable;

  function depositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount) external payable;

  function deallocateMatrix(address hubMatrixVault, uint256 amount) external payable;

  function settleMatrixYield(address hubMatrixVault, uint256 amount) external payable;

  function settleMatrixLoss(address hubMatrixVault, uint256 amount) external payable;

  function settleMatrixExtraRewards(address hubMatrixVault, address reward, uint256 amount) external payable;
}
