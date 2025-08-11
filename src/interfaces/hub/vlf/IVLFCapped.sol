// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IVLF } from './IVLF.sol';

interface IVLFCapped is IVLF {
  function loadCap() external view returns (uint256);

  function loadSoftCap() external view returns (uint256);

  function isPreferredChain(uint256 chainId) external view returns (bool);

  function preferredChainIds() external view returns (uint256[] memory);
}
