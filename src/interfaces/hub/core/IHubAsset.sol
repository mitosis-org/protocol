// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20TwabSnapshots } from '../../twab/IERC20TwabSnapshots.sol';

interface IHubAsset is IERC20TwabSnapshots {
  /// temp: onlyAssetManager
  function mint(address to, uint256 amount) external;

  function burn(uint256 amount) external;

  function burnFrom(address from, uint256 amount) external;
}
