// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20TWABSnapshots } from '../../twab/IERC20TWABSnapshots.sol';

interface IHubAsset is IERC20TWABSnapshots {
  function mint(address account, uint256 value) external;
  function burn(address account, uint256 value) external;
}
