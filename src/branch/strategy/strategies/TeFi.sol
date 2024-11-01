// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Initializable } from '@oz-v5/proxy/utils/Initializable.sol';
import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { ITeFi } from '../../../interfaces/branch/strategy/ITeFi.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';

/**
 * @title TeFi
 * @notice Simple DeFi contract for testnet
 */
contract TeFi is ITeFi, Initializable {
  using SafeERC20 for IERC20;

  IERC20 internal immutable _asset;
  address internal immutable _strategyExecutor;
  bytes32 internal immutable _name;

  modifier onlyStrategyExecutor() {
    require(msg.sender == _strategyExecutor, StdError.Unauthorized());
    _;
  }

  constructor(address strategyExecutor_, address asset_, string memory name_) {
    _strategyExecutor = strategyExecutor_;
    _asset = IERC20(asset_);
    require(bytes(name_).length < 32, 'TeFi: name too long');
    _name = bytes32(bytes(name_));

    _disableInitializers();
  }

  function initialize() external initializer {
    // to nothing
  }

  function name() external view returns (string memory) {
    return string(abi.encodePacked(_name));
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
