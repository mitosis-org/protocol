// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import '@oz-v5/interfaces/IERC20.sol';
import '@oz-v5/interfaces/IERC20Metadata.sol';

import './ISnapshots.sol';

interface IERC20Snapshots is IERC20, IERC20Metadata, ISnapshots { }
