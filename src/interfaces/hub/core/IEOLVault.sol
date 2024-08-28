// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC4626TwabSnapshots } from '../../twab/IERC4626TwabSnapshots.sol';

interface IEOLVault is IERC4626TwabSnapshots {
  function eolId() external view returns (uint256);

  function assignEolId(uint256 eolId) external;
}
