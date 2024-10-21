// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';

interface ITeFi {
  error ITeFi__InsufficientDepositAmount();

  function name() external view returns (string memory);
  function asset() external view returns (IERC20);
  function claimableAmount(address asset) external view returns (uint256);
  function claim(address asset_, uint256 amount) external;
  function withdraw(uint256 amount) external;
}
