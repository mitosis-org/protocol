// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Context } from '@oz-v5/utils/Context.sol';

import { IAssetManager } from '../../src/interfaces/hub/core/IAssetManager.sol';
import { IAssetManagerEntrypoint } from '../../src/interfaces/hub/core/IAssetManagerEntrypoint.sol';
import { StdError } from '../../src/lib/StdError.sol';

contract MockAssetManagerEntrypoint is Context, IAssetManagerEntrypoint {
  IAssetManager internal _assetManager;
  address internal _mailbox;

  modifier onlyAssetManager() {
    require(_msgSender() == address(_assetManager), StdError.Unauthorized());
    _;
  }

  modifier onlyMailbox() {
    require(_msgSender() == _mailbox, StdError.Unauthorized());
    _;
  }

  constructor(IAssetManager assetManager_, address mailbox) {
    _assetManager = assetManager_;
    _mailbox = mailbox;
  }

  function assetManager() external view returns (IAssetManager assetManger_) {
    return _assetManager;
  }

  function branchDomain(uint256) external pure returns (uint32) {
    return 0;
  }

  function branchVault(uint256) external pure returns (address) {
    return address(0);
  }

  function branchEntrypointAddr(uint256) external pure returns (address) {
    return address(0);
  }

  // ============================= NOTE: DISPATCHER ============================= //

  function initializeAsset(uint256 chainId, address branchAsset) external onlyAssetManager { }

  function initializeEOL(uint256 chainId, address eolVault, address branchAsset) external onlyAssetManager { }

  function redeem(uint256 chainId, address branchAsset, address to, uint256 amount) external onlyAssetManager { }

  function allocateEOL(uint256 chainId, address eolVault, uint256 amount) external onlyAssetManager { }

  // ============================= NOTE: PROCESSOR ============================= //

  function deposit(uint256 chainId, address branchAsset, address to, uint256 amount) external onlyMailbox {
    _assetManager.deposit(chainId, branchAsset, to, amount);
  }

  function deallocateEOL(uint256 chainId, address eolVault, uint256 amount) external onlyMailbox {
    _assetManager.deallocateEOL(chainId, eolVault, amount);
  }

  function settleYield(uint256 chainId, address eolVault, uint256 amount) external onlyMailbox {
    _assetManager.settleYield(chainId, eolVault, amount);
  }

  function settleLoss(uint256 chainId, address eolVault, uint256 amount) external onlyMailbox {
    _assetManager.settleLoss(chainId, eolVault, amount);
  }

  function settleExtraRewards(uint256 chainId, address eolVault, address reward, uint256 amount) external onlyMailbox {
    _assetManager.settleExtraRewards(chainId, eolVault, reward, amount);
  }

  // ============================= NOTE: HANDLER ============================= //

  function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override { }
}
