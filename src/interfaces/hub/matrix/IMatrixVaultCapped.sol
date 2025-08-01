// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMatrixVault } from './IMatrixVault.sol';

interface IMatrixVaultCapped is IMatrixVault {
  function loadCap() external view returns (uint256);

  function setCap(uint256 cap_) external;
}
