// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC5805 } from '@oz-v5/interfaces/IERC5805.sol';

interface IERC5805TWAB is IERC5805 {
  function getVoteSnapshot(address account) external view returns (uint208 balance, uint256 twab, uint48 position);

  function getPastVoteSnapshot(address account, uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);
}
