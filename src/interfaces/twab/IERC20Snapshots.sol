// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import '@oz-v5/interfaces/IERC20.sol';
import '@oz-v5/interfaces/IERC20Metadata.sol';

import './ISnapshots.sol';

/**
 * @title IERC20Snapshots
 * @dev Interface for ERC20 tokens with snapshots functionality.
 */
interface IERC20Snapshots is IERC20, IERC20Metadata, ISnapshots { }
