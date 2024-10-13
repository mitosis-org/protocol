// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMitosisVault } from './IMitosisVault.sol';

interface IMitosisVaultEntrypoint {
  function vault() external view returns (IMitosisVault);

  function mitosisDomain() external view returns (uint32);

  function mitosisAddr() external view returns (bytes32);

  function deposit(address asset, address to, uint256 amount) external;

  function depositWithOptIn(address asset, address to, address hubEOLVault, uint256 amount) external;

  function deallocateEOL(address hubEOLVault, uint256 amount) external;

  function settleYield(address hubEOLVault, uint256 amount) external;

  function settleLoss(address hubEOLVault, uint256 amount) external;

  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external;
}
