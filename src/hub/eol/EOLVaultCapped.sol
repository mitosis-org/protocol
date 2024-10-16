// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Math } from '@oz-v5/utils/math/Math.sol';

import { IERC20TWABSnapshots } from '../../interfaces/twab/IERC20TWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { EOLVault } from './EOLVault.sol';

/**
 * @title EOLVaultCapped
 * @notice Adds a cap to the EOLVault's deposit / mint function
 */
contract EOLVaultCapped is EOLVault {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.EOLVaultCapped
  struct EOLVaultCappedStorage {
    uint256 cap;
  }

  event CapSet(address indexed setter, uint256 prevCap, uint256 newCap);

  error CapFulfilled();

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.EOLVaultCapped';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getEOLVaultCappedStorage() private view returns (EOLVaultCappedStorage storage $) {
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

  function initialize(
    address delegationRegistry_,
    address assetManager_,
    IERC20TWABSnapshots asset_,
    string memory name,
    string memory symbol
  ) external initializer {
    __EOLVault_init(delegationRegistry_, assetManager_, asset_, name, symbol);

    EOLVaultCappedStorage storage $ = _getEOLVaultCappedStorage();
    $.cap = 0;
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function loadCap() external view returns (uint256) {
    return _getEOLVaultCappedStorage().cap;
  }

  function previewDeposit(uint256 assets) public view override returns (uint256) {
    uint256 shares = super.previewDeposit(assets);
    return _simulateMint(shares); // in shares
  }

  function previewMint(uint256 shares) public view override returns (uint256) {
    uint256 simulatedShares = _simulateMint(shares);
    return super.previewMint(simulatedShares); // in assets
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function setCap(uint256 newCap) external {
    StorageV1 storage $ = _getStorageV1();
    EOLVaultCappedStorage storage capped = _getEOLVaultCappedStorage();

    _assertOnlyAssetManager($);

    _setCap(capped, newCap);
  }

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    uint256 shares = previewDeposit(assets);
    return super.deposit(shares, receiver);
  }

  function mint(uint256 shares, address receiver) public override returns (uint256) {
    uint256 simulatedShares = _simulateMint(shares);
    return super.mint(simulatedShares, receiver);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _simulateMint(uint256 shares) internal view returns (uint256) {
    uint256 totalShares = totalSupply();

    uint256 cap = _getEOLVaultCappedStorage().cap;

    require(totalShares > cap, CapFulfilled());

    return Math.min(shares, cap - totalShares);
  }

  function _setCap(EOLVaultCappedStorage storage $, uint256 newCap) internal {
    uint256 prevCap = $.cap;
    $.cap = newCap;
    emit CapSet(_msgSender(), prevCap, newCap);
  }
}
