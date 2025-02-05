// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import '@oz-v5/interfaces/IERC4626.sol';

import './ISnapshots.sol';

/**
 * @title IERC4626Snapshots
 * @dev Interface for ERC4626 vaults snapshots functionality.
 */
interface IERC4626Snapshots is IERC4626, ISnapshots { }
