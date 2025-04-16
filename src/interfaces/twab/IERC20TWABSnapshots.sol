// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import '@oz-v5/interfaces/IERC20.sol';
import '@oz-v5/interfaces/IERC20Metadata.sol';

import './ITWABSnapshots.sol';

/**
 * @title IERC20TWABSnapshots
 * @dev Interface for ERC20 tokens with Time-Weighted Average Balance (TWAB) snapshots functionality.
 */
interface IERC20TWABSnapshots is IERC20, IERC20Metadata, ITWABSnapshots { }
