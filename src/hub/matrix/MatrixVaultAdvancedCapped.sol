// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { Math } from '@oz/utils/math/Math.sol';
import { EnumerableSet } from '@oz/utils/structs/EnumerableSet.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { MatrixVaultCapped } from './MatrixVaultCapped.sol';

/**
 * @title MatrixVaultAdvancedCapped
 * @notice Advanced capped MatrixVault with soft cap and preferred chain bypass functionality
 */
contract MatrixVaultAdvancedCapped is MatrixVaultCapped {
  using ERC7201Utils for string;
  using EnumerableSet for EnumerableSet.UintSet;

  /// @custom:storage-location mitosis.storage.MatrixVaultAdvancedCapped
  struct MatrixVaultAdvancedCappedStorage {
    uint256 softCap;
    EnumerableSet.UintSet preferredChainIds;
  }

  event SoftCapSet(uint256 prevSoftCap, uint256 newSoftCap);
  event PreferredChainAdded(uint256 indexed chainId);
  event PreferredChainRemoved(uint256 indexed chainId);

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.MatrixVaultAdvancedCapped';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getAdvancedCappedStorage() private view returns (MatrixVaultAdvancedCappedStorage storage $) {
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
    override
    initializer
  {
    super.initialize(assetManager_, asset_, name, symbol);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function maxDeposit(address receiver) public view override returns (uint256) {
    return _maxDepositInternal(_getAdvancedCappedStorage(), receiver, true, 0);
  }

  function maxDepositFromChainId(address receiver, uint256 chainId) public view override returns (uint256) {
    return _maxDepositInternal(_getAdvancedCappedStorage(), receiver, false, chainId);
  }

  function loadSoftCap() external view returns (uint256) {
    return _getAdvancedCappedStorage().softCap;
  }

  function isPreferredChain(uint256 chainId) external view returns (bool) {
    return _getAdvancedCappedStorage().preferredChainIds.contains(chainId);
  }

  function preferredChainIds() external view returns (uint256[] memory) {
    return _getAdvancedCappedStorage().preferredChainIds.values();
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function setSoftCap(uint256 newSoftCap) external onlyLiquidityManager {
    _setSoftCap(_getAdvancedCappedStorage(), newSoftCap);
  }

  function addPreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _addPreferredChainId(_getAdvancedCappedStorage(), chainId);
  }

  function removePreferredChainId(uint256 chainId) external onlyLiquidityManager {
    _removePreferredChainId(_getAdvancedCappedStorage(), chainId);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _maxDepositInternal(
    MatrixVaultAdvancedCappedStorage storage $,
    address receiver,
    bool enforceSoftCap,
    uint256 chainId
  ) internal view returns (uint256) {
    uint256 hardCapLimit = MatrixVaultCapped.maxDeposit(receiver);

    // If this is a preferred chain (when enforceSoftCap is false), bypass soft cap
    if (!enforceSoftCap && $.preferredChainIds.contains(chainId)) {
      return hardCapLimit;
    }

    // Otherwise apply soft cap
    uint256 currentAssets = totalAssets();
    uint256 softCapLimit = currentAssets >= $.softCap ? 0 : $.softCap - currentAssets;

    return Math.min(hardCapLimit, softCapLimit);
  }

  function _setSoftCap(MatrixVaultAdvancedCappedStorage storage $, uint256 newSoftCap) internal {
    uint256 prevSoftCap = $.softCap;
    $.softCap = newSoftCap;
    emit SoftCapSet(prevSoftCap, newSoftCap);
  }

  function _addPreferredChainId(MatrixVaultAdvancedCappedStorage storage $, uint256 chainId) internal {
    $.preferredChainIds.add(chainId);
    emit PreferredChainAdded(chainId);
  }

  function _removePreferredChainId(MatrixVaultAdvancedCappedStorage storage $, uint256 chainId) internal {
    $.preferredChainIds.remove(chainId);
    emit PreferredChainRemoved(chainId);
  }
}
