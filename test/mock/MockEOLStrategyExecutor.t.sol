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

  function vault() external view returns (IMitosisVault) {
    return _vault;
  }

  function asset() external view returns (IERC20) {
    return _asset;
  }

  function hubEOLVault() external view returns (address) {
    return _hubEOLVault;
  }

  function strategist() external view returns (address) { }
  function strategyId(address implementation) external view returns (uint256) { }

  function getStrategy(uint256 strategyId_) external view returns (Strategy memory) { }
  function getStrategy(address implementation) external view returns (Strategy memory) { }
  function getEnabledStrategyIds() external view returns (uint256[] memory) { }
  function isStrategyEnabled(uint256 strategyId_) external view returns (bool) { }
  function isStrategyEnabled(address implementation) external view returns (bool) { }

  function totalBalance() external view returns (uint256) {
    return _asset.balanceOf(address(this));
  }

  function storedTotalBalance() external view returns (uint256) { }

  function fetchEOL(uint256 amount) external { }

  function returnEOL(uint256 amount) external {
    _asset.approve(address(_vault), amount);
    _vault.returnEOL(_hubEOLVault, amount);
  }

  function settle() external { }
  function settleExtraRewards(address reward, uint256 amount) external { }
  function execute(Call[] calldata calls) external { }
}
