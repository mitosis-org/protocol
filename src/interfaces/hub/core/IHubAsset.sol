// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20TwabSnapshots } from '../../twab/IERC20TwabSnapshots.sol';

interface IHubAsset is IERC20TwabSnapshots {
  function mint(address account, uint256 value) external;
  function burn(address account, uint256 value) external;
}
