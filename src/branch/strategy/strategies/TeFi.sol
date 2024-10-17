// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';

interface ITeFi {
  error ITeFi__InsufficientDepositAmount();

  function name() external view returns (string memory);
  function asset() external view returns (IERC20);
  function claimableAmount(address asset) external view returns (uint256);
  function claim(address asset_, uint256 amount) external;
  function withdraw(uint256 amount) external;
}

/**
 * @title TeFi
 * @notice Simple DeFi contract for testnet
 */
contract TeFi is ITeFi {
  using SafeERC20 for IERC20;

  IERC20 internal immutable _asset;
  address internal immutable _strategyExecutor;
  string internal _name;

  modifier onlyStrategyExecutor() {
    require(msg.sender == _strategyExecutor, StdError.Unauthorized());
    _;
  }

  constructor(address strategyExecutor_, address asset_, string memory name_) {
    _strategyExecutor = strategyExecutor_;
    _asset = IERC20(asset_);
    _name = name_;
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function asset() external view returns (IERC20) {
    return _asset;
  }

  function claimableAmount(address asset_) external view returns (uint256) {
    return IERC20(asset_).balanceOf(address(this));
  }

  function claim(address asset_, uint256 amount) external onlyStrategyExecutor {
    IERC20(asset_).transferFrom(msg.sender, address(this), amount);
  }

  // deposit: Just transfer token to TestnetDeFi

  function withdraw(uint256 amount) external onlyStrategyExecutor {
    _asset.transfer(msg.sender, amount);
  }

  // triggerYield: Just transfer token to TestnetDeFi

  function triggerLoss(uint256 amount) external onlyStrategyExecutor {
    _asset.transfer(0x000000000000000000000000000000000000dEaD, amount);
  }
}
