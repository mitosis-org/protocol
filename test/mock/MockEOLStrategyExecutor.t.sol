// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IEOLStrategyExecutor } from '../../src/interfaces/branch/strategy/IEOLStrategyExecutor.sol';

contract MockEOLStrategyExecutor is IEOLStrategyExecutor {
  IMitosisVault _vault;
  IERC20 _asset;
  address _hubEOLVault;

  constructor(IMitosisVault vault_, IERC20 asset_, address hubEOLVault_) {
    _vault = vault_;
    _asset = asset_;
    _hubEOLVault = hubEOLVault_;
  }

  function vault() external view returns (IMitosisVault vault_) {
    return _vault;
  }

  function asset() external view returns (IERC20 asset_) {
    return _asset;
  }

  function hubEOLVault() external view returns (address hubEOLVault_) {
    return _hubEOLVault;
  }

  function strategist() external view returns (address strategist_) { }

  function getStrategy(uint256 strategyId) external view returns (Strategy memory strategy) { }
  function getStrategy(address implementation) external view returns (Strategy memory strategy) { }
  function getEnabledStrategyIds() external view returns (uint256[] memory strategyIds) { }
  function isStrategyEnabled(uint256 strategyId) external view returns (bool enabled) { }
  function isStrategyEnabled(address implementation) external view returns (bool enabled) { }

  function totalBalance() external view returns (uint256 totalBalance_) {
    return _asset.balanceOf(address(this));
  }

  function lastSettledBalance() external view returns (uint256 lastSettledBalance_) { }

  function fetchEOL(uint256 amount) external { }

  function returnEOL(uint256 amount) external {
    _asset.approve(address(_vault), amount);
    _vault.returnEOL(_hubEOLVault, amount);
  }

  function settle() external { }
  function settleExtraRewards(address reward, uint256 amount) external { }
  function execute(Call[] calldata calls) external { }
}
