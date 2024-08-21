// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

interface IHubAsset is IERC20 {
  /// temp: onlyAssetManager
  function mint(address to, uint256 amount) external;

  function burn(uint256 amount) external;

  function burnFrom(address from, uint256 amount) external;
}
