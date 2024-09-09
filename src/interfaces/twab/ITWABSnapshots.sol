// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';

interface ITWABSnapshots is IERC6372 {
  function getLatestSnapshot(address account) external view returns (uint208 balnace, uint256 twab, uint48 position);

  function getPastSnapshot(address account, uint256 timestamp)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);

  function getLatestTotalSnapshot() external view returns (uint208 balance, uint256 twab, uint48 position);

  function getPastTotalSnapshot(uint256 timestamp)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);
}
