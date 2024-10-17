// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IEOLVault } from './IEOLVault.sol';

interface IEOLVaultCapped is IEOLVault {
  function loadCap() external view returns (uint256);

  function setCap(uint256 cap_) external;
}
