// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMatrixVaultCapped } from './IMatrixVaultCapped.sol';

/**
 * @title IMatrixVaultAdvancedCapped
 * @notice Extended interface for MatrixVaultCapped with soft cap and preferred chain bypass features
 */
interface IMatrixVaultAdvancedCapped is IMatrixVaultCapped {
  function loadSoftCap() external view returns (uint256);

  function isPreferredChain(uint256 chainId) external view returns (bool);

  function preferredChainIds() external view returns (uint256[] memory);
}
