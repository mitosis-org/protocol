// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Initializable } from '@oz-v5/proxy/utils/Initializable.sol';
import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';

import { ITeFi } from '../../../interfaces/branch/strategy/ITeFi.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { StdError } from '../../../lib/StdError.sol';
import { StdStrategy } from './StdStrategy.sol';

/**
 * @title TeFi
 * @notice Simple DeFi contract for testnet
 */
contract TeFi is ITeFi, Initializable {
  using SafeERC20 for IERC20;

  using ERC7201Utils for string;

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  struct Storage {
    IERC20 asset;
    address strategyExecutor;
    string name;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TracleAggregatorV2V3';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorage() internal view returns (Storage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  modifier onlyStrategyExecutor() {
    require(msg.sender == _getStorage().strategyExecutor, StdError.Unauthorized());
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address strategyExecutor_, address asset_, string memory name_) external initializer {
    Storage storage $ = _getStorage();
    $.strategyExecutor = strategyExecutor_;
    $.asset = IERC20(asset_);
    $.name = name_;
  }

  function name() external view returns (string memory) {
    return _getStorage().name;
  }

  function asset() external view returns (IERC20) {
    return _getStorage().asset;
  }

  function claimableAmount(address asset_) external view returns (uint256) {
    return IERC20(asset_).balanceOf(address(this));
  }

  function claim(address asset_, uint256 amount) external onlyStrategyExecutor {
    IERC20(asset_).transferFrom(msg.sender, address(this), amount);
  }

  // deposit: Just transfer token to TestnetDeFi

  function withdraw(uint256 amount) external onlyStrategyExecutor {
    _getStorage().asset.transfer(msg.sender, amount);
  }

  // triggerYield: Just transfer token to TestnetDeFi

  function triggerLoss(uint256 amount) external onlyStrategyExecutor {
    _getStorage().asset.transfer(0x000000000000000000000000000000000000dEaD, amount);
  }
}
