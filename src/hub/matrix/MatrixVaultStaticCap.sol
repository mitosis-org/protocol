// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { Math } from '@oz/utils/math/Math.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { MatrixVault } from './MatrixVault.sol';

/**
 * @title MatrixVaultStaticCap
 * @notice Adds a cap to the MatrixVault's deposit / mint function
 */
contract MatrixVaultStaticCap is MatrixVault {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.MatrixVaultStaticCap
  struct MatrixVaultStaticCapStorage {
    uint256 cap;
  }

  event CapSet(address indexed setter, uint256 prevCap, uint256 newCap);

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.MatrixVaultStaticCap';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getMatrixVaultStaticCapStorage() private view returns (MatrixVaultStaticCapStorage storage $) {
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
    external
    initializer
  {
    __MatrixVault_init(assetManager_, asset_, name, symbol);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function loadCap() external view returns (uint256) {
    return _getMatrixVaultStaticCapStorage().cap;
  }

  function maxDeposit(address) public view override returns (uint256 maxAssets) {
    uint256 _cap = _getMatrixVaultStaticCapStorage().cap;
    uint256 _totalAssets = totalAssets();
    return _totalAssets >= _cap ? 0 : _cap - _totalAssets;
  }

  function maxMint(address account) public view override returns (uint256 maxShares) {
    return convertToShares(maxDeposit(account));
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function setCap(uint256 newCap) external onlyOwner {
    _setCap(_getMatrixVaultStaticCapStorage(), newCap);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _setCap(MatrixVaultStaticCapStorage storage $, uint256 newCap) internal {
    uint256 prevCap = $.cap;
    $.cap = newCap;
    emit CapSet(_msgSender(), prevCap, newCap);
  }
}
