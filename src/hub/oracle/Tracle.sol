// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { ITracle } from '../../interfaces/hub/oracle/ITracle.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

contract Tracle is ITracle, Ownable2StepUpgradeable, AccessControlUpgradeable {
  using ERC7201Utils for string;

  bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

  modifier onlyManager() {
    _checkRole(MANAGER_ROLE);
    _;
  }

  /// @custom:storage-location mitosis.storage.Tracle
  struct TracleStorage {
    mapping(bytes32 id => Price) prices;
    mapping(bytes32 id => EOLVaultPriceConfig) eolVaultPriceConfigs;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.Tracle';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getTracleStorage() internal view returns (TracleStorage storage $) {
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

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    __AccessControl_init();

    _transferOwnership(owner);
    _grantRole(DEFAULT_ADMIN_ROLE, owner);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function getPrice(bytes32 id) external view returns (Price memory) {
    TracleStorage storage $ = _getTracleStorage();
    EOLVaultPriceConfig storage config = $.eolVaultPriceConfigs[id];

    if (config.eolVault != address(0)) {
      return _getEOLVaultPrice($, IEOLVault(config.eolVault), config.underlyingPriceId);
    } else {
      return _getStoredPrice($, id);
    }
  }

  function getEOLVaultPriceConfig(bytes32 id) external view returns (EOLVaultPriceConfig memory) {
    TracleStorage storage $ = _getTracleStorage();
    require($.eolVaultPriceConfigs[id].eolVault != address(0), ITracle__InvalidPriceId(id));
    return $.eolVaultPriceConfigs[id];
  }

  // ============================ NOTE: MANAGEMENT FUNCTIONS ============================ //

  function updatePrice(bytes32 id, uint208 price) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();
    uint48 currentTime = Time.timestamp();

    $.prices[id] = Price({ price: price, updatedAt: currentTime });
    emit PriceUpdated(id, price, currentTime);
  }

  function updatePrices(bytes32[] memory ids, uint208[] memory prices) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();
    uint48 currentTime = Time.timestamp();

    require(ids.length == prices.length, StdError.InvalidParameter('ids, prices'));

    for (uint256 i = 0; i < ids.length; i++) {
      $.prices[ids[i]] = Price({ price: prices[i], updatedAt: currentTime });
      emit PriceUpdated(ids[i], prices[i], currentTime);
    }
  }

  function setEOLVaultPriceConfig(bytes32 id, EOLVaultPriceConfig memory config) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();

    $.eolVaultPriceConfigs[id] = config;
    emit EOLVaultPriceConfigSet(id, config.eolVault, config.underlyingPriceId);
  }

  function unsetEOLVaultPriceConfig(bytes32 id) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();

    delete $.eolVaultPriceConfigs[id];
    emit EOLVaultPriceConfigUnset(id);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _getStoredPrice(TracleStorage storage $, bytes32 id) internal view returns (Price memory) {
    require($.prices[id].updatedAt != 0, ITracle__InvalidPriceId(id));
    return $.prices[id];
  }

  function _getEOLVaultPrice(TracleStorage storage $, IEOLVault eolVault, bytes32 underlyingPriceId)
    internal
    view
    returns (Price memory)
  {
    Price memory underlyingPrice = _getStoredPrice($, underlyingPriceId);
    uint208 price = SafeCast.toUint208(underlyingPrice.price * eolVault.totalAssets() / eolVault.totalSupply());
    return Price({ price: price, updatedAt: underlyingPrice.updatedAt });
  }
}
