// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { Math } from '@oz/utils/math/Math.sol';
import { EnumerableSet } from '@oz/utils/structs/EnumerableSet.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { MatrixVault } from './MatrixVault.sol';

/**
 * @title MatrixVaultCapped
 * @notice MatrixVault with a cap system
 */
contract MatrixVaultCapped is MatrixVault {
  using ERC7201Utils for string;
  using EnumerableSet for EnumerableSet.UintSet;

  /// @custom:storage-location mitosis.storage.MatrixVaultCapped
  struct MatrixVaultCappedStorage {
    uint256 cap;
    uint256 softCap;
    EnumerableSet.UintSet preferredChainIds;
  }

  event CapSet(address indexed setter, uint256 prevCap, uint256 newCap);
  event SoftCapSet(uint256 prevSoftCap, uint256 newSoftCap);
  event PreferredChainAdded(uint256 indexed chainId);
  event PreferredChainRemoved(uint256 indexed chainId);

  modifier onlyLiquidityManager() {
    require(_getStorageV1().assetManager.isLiquidityManager(_msgSender()), StdError.Unauthorized());
    _;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.MatrixVaultCapped';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getMatrixVaultCappedStorage() private view returns (MatrixVaultCappedStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  function initialize(address assetManager_, IERC20Metadata asset_, string memory name, string memory symbol)
    public
    virtual
    initializer
  {
    __MatrixVault_init(assetManager_, asset_, name, symbol);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function loadCap() external view returns (uint256) {
    return _getMatrixVaultCappedStorage().cap;
  }

  function loadSoftCap() external view returns (uint256) {
    return _getMatrixVaultCappedStorage().softCap;
  }

  function isPreferredChain(uint256 chainId) external view returns (bool) {
    return _getMatrixVaultCappedStorage().preferredChainIds.contains(chainId);
  }

  function preferredChainIds() external view returns (uint256[] memory) {
    return _getMatrixVaultCappedStorage().preferredChainIds.values();
  }

  function maxDeposit(address) public view virtual override returns (uint256 maxAssets) {
    return _maxDepositForAllCaps(_getMatrixVaultCappedStorage());
  }

  function maxDepositFromChainId(address, /*receiver*/ uint256 chainId) public view virtual override returns (uint256) {
    MatrixVaultCappedStorage storage $ = _getMatrixVaultCappedStorage();

    if ($.preferredChainIds.contains(chainId)) {
      return _maxDepositForHardCap($);
    } else {
      return _maxDepositForAllCaps($);
    }
  }

  function maxMint(address account) public view override returns (uint256 maxShares) {
    return convertToShares(maxDeposit(account));
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function setCap(uint256 newCap) external onlyLiquidityManager {
    _setCap(_getMatrixVaultCappedStorage(), newCap);
  }

  function setSoftCap(uint256 newSoftCap) external onlyLiquidityManager {
    _setSoftCap(_getMatrixVaultCappedStorage(), newSoftCap);
  }

  function addPreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _addPreferredChainId(_getMatrixVaultCappedStorage(), chainId);
  }

  function removePreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _removePreferredChainId(_getMatrixVaultCappedStorage(), chainId);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _maxDepositForAllCaps(MatrixVaultCappedStorage storage $) internal view returns (uint256) {
    uint256 currentAssets = totalAssets();
    uint256 capLimit = currentAssets >= $.cap ? 0 : $.cap - currentAssets;
    uint256 softCapLimit = currentAssets >= $.softCap ? 0 : $.softCap - currentAssets;
    return Math.min(capLimit, softCapLimit);
  }

  function _maxDepositForHardCap(MatrixVaultCappedStorage storage $) internal view returns (uint256) {
    uint256 currentAssets = totalAssets();
    return currentAssets >= $.cap ? 0 : $.cap - currentAssets;
  }

  function _setCap(MatrixVaultCappedStorage storage $, uint256 newCap) internal {
    uint256 prevCap = $.cap;
    $.cap = newCap;
    emit CapSet(_msgSender(), prevCap, newCap);
  }

  function _setSoftCap(MatrixVaultCappedStorage storage $, uint256 newSoftCap) internal {
    uint256 prevSoftCap = $.softCap;
    $.softCap = newSoftCap;
    emit SoftCapSet(prevSoftCap, newSoftCap);
  }

  function _addPreferredChainId(MatrixVaultCappedStorage storage $, uint256 chainId) internal {
    if ($.preferredChainIds.add(chainId)) {
      emit PreferredChainAdded(chainId);
    }
  }

  function _removePreferredChainId(MatrixVaultCappedStorage storage $, uint256 chainId) internal {
    if ($.preferredChainIds.remove(chainId)) {
      emit PreferredChainRemoved(chainId);
    }
  }
}
