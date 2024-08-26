// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626 } from '@oz-v5/interfaces/IERC4626.sol';

interface IEOLVault is IERC4626 {
  function assignEolId(uint256 eolId) external;

  function reduceAssetManagerAllowance(uint256 value) external;
}
