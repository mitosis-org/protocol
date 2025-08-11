// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { Math } from '@oz/utils/math/Math.sol';
import { EnumerableSet } from '@oz/utils/structs/EnumerableSet.sol';

import { IAssetManager } from '../../interfaces/hub/core/IAssetManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { VLF } from './VLF.sol';

/**
 * @title VLFCapped
 * @notice VLF with a cap system
 */
contract VLFCapped is VLF {
  using ERC7201Utils for string;
  using EnumerableSet for EnumerableSet.UintSet;

  /// @custom:storage-location mitosis.storage.VLFCapped
  struct VLFCappedStorage {
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

  string private constant _NAMESPACE = 'mitosis.storage.VLFCapped';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getVLFCappedStorage() private view returns (VLFCappedStorage storage $) {
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
    __VLF_init(assetManager_, asset_, name, symbol);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function loadCap() external view returns (uint256) {
    return _getVLFCappedStorage().cap;
  }

  function loadSoftCap() external view returns (uint256) {
    return _getVLFCappedStorage().softCap;
  }

  function isPreferredChain(uint256 chainId) external view returns (bool) {
    return _getVLFCappedStorage().preferredChainIds.contains(chainId);
  }

  function preferredChainIds() external view returns (uint256[] memory) {
    return _getVLFCappedStorage().preferredChainIds.values();
  }

  function maxDeposit(address) public view virtual override returns (uint256 maxAssets) {
    return _maxDepositForAllCaps(_getVLFCappedStorage());
  }

  function maxDepositFromChainId(address, /*receiver*/ uint256 chainId) public view virtual override returns (uint256) {
    VLFCappedStorage storage $ = _getVLFCappedStorage();

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
    _setCap(_getVLFCappedStorage(), newCap);
  }

  function setSoftCap(uint256 newSoftCap) external onlyLiquidityManager {
    _setSoftCap(_getVLFCappedStorage(), newSoftCap);
  }

  function addPreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _addPreferredChainId(_getVLFCappedStorage(), chainId);
  }

  function removePreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _removePreferredChainId(_getVLFCappedStorage(), chainId);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _maxDepositForAllCaps(VLFCappedStorage storage $) internal view returns (uint256) {
    uint256 currentAssets = totalAssets();
    uint256 capLimit = currentAssets >= $.cap ? 0 : $.cap - currentAssets;
    uint256 softCapLimit = currentAssets >= $.softCap ? 0 : $.softCap - currentAssets;
    return Math.min(capLimit, softCapLimit);
  }

  function _maxDepositForHardCap(VLFCappedStorage storage $) internal view returns (uint256) {
    uint256 currentAssets = totalAssets();
    return currentAssets >= $.cap ? 0 : $.cap - currentAssets;
  }

  function _setCap(VLFCappedStorage storage $, uint256 newCap) internal {
    uint256 prevCap = $.cap;
    $.cap = newCap;
    emit CapSet(_msgSender(), prevCap, newCap);
  }

  function _setSoftCap(VLFCappedStorage storage $, uint256 newSoftCap) internal {
    uint256 prevSoftCap = $.softCap;
    $.softCap = newSoftCap;
    emit SoftCapSet(prevSoftCap, newSoftCap);
  }

  function _addPreferredChainId(VLFCappedStorage storage $, uint256 chainId) internal {
    if ($.preferredChainIds.add(chainId)) {
      emit PreferredChainAdded(chainId);
    }
  }

  function _removePreferredChainId(VLFCappedStorage storage $, uint256 chainId) internal {
    if ($.preferredChainIds.remove(chainId)) {
      emit PreferredChainRemoved(chainId);
    }
  }
}
