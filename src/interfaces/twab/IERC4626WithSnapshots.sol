// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import '@oz-v5/interfaces/IERC4626.sol';

import './ISnapshots.sol';

interface IERC4626WithSnapshots is IERC4626, ISnapshots { }
