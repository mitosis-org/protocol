// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC5805 } from '@oz-v5/interfaces/IERC5805.sol';

interface ITWABSnapshots is IERC5805 {
  error ERC6372InconsistentClock();

  error ERC5805FutureLookup(uint256 timestamp, uint256 now_);

  function totalSupplySnapshot() external view returns (uint208 balance, uint256 twab, uint48 position);

  function totalSupplySnapshot(uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);

  function balanceSnapshot(address account, uint256 timepoint) external view returns (uint208 balance);

  function delegateSnapshot(address account) external view returns (uint208 balance, uint256 twab, uint48 position);

  function delegateSnapshot(address account, uint256 timepoint)
    external
    view
    returns (uint208 balance, uint256 twab, uint48 position);

  /**
   * @dev Delegates from account to `delegatee` by manager.
   */
  function delegateByManager(address account, address delegatee) external;
}
