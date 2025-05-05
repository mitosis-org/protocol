// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/token/ERC20/IERC20.sol';

interface ITeFi {
  function name() external view returns (string memory);
  function asset() external view returns (IERC20);
  function claimableAmount(address asset_) external view returns (uint256);
  function claim(address asset_, uint256 amount) external;
  function withdraw(uint256 amount) external;
  function triggerLoss(uint256 amount) external;
}
