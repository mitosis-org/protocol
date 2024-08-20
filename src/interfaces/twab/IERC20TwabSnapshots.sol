// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import '@oz-v5/interfaces/IERC20.sol';
import '@oz-v5/interfaces/IERC20Metadata.sol';

import './ITwabSnapshots.sol';

interface IERC20TwabSnapshots is IERC20, IERC20Metadata, ITwabSnapshots { }
