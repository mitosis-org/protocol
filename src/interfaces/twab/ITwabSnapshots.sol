// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITwabSnapshots {
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
