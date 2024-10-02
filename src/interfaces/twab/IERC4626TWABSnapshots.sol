// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import '@oz-v5/interfaces/IERC4626.sol';

import './ITWABSnapshots.sol';

/**
 * @title IERC4626TWABSnapshots
 * @dev Interface for ERC4626 vaults with Time-Weighted Average Balance (TWAB) snapshots functionality.
 */
interface IERC4626TWABSnapshots is IERC4626, ITWABSnapshots { }
