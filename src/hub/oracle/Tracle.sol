// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { ITracle } from '../../interfaces/hub/oracle/ITracle.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

/**
 * @title Tracle
 * @notice A temporary oracle contract only for testnet.
 */
contract Tracle is ITracle, AccessControlUpgradeable {
  using ERC7201Utils for string;

  bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

  modifier onlyManager() {
    _checkRole(MANAGER_ROLE);
    _;
  }

  /// @custom:storage-location mitosis.storage.Tracle
  struct TracleStorage {
    mapping(bytes32 id => Price) prices;
    mapping(bytes32 id => MatrixVaultPriceConfig) matrixVaultPriceConfigs;
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
    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, owner);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function getPrice(bytes32 id) external view returns (Price memory) {
    TracleStorage storage $ = _getTracleStorage();
    MatrixVaultPriceConfig storage config = $.matrixVaultPriceConfigs[id];

    if (config.matrixVault != address(0)) {
      return _getMatrixVaultPrice($, IMatrixVault(config.matrixVault), config.underlyingPriceId);
    } else {
      return _getStoredPrice($, id);
    }
  }

  function getMatrixVaultPriceConfig(bytes32 id) external view returns (MatrixVaultPriceConfig memory) {
    TracleStorage storage $ = _getTracleStorage();
    require($.matrixVaultPriceConfigs[id].matrixVault != address(0), ITracle__InvalidPriceId(id));
    return $.matrixVaultPriceConfigs[id];
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

  function setMatrixVaultPriceConfig(bytes32 id, MatrixVaultPriceConfig memory config) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();

    $.matrixVaultPriceConfigs[id] = config;
    emit MatrixVaultPriceConfigSet(id, config.matrixVault, config.underlyingPriceId);
  }

  function unsetMatrixVaultPriceConfig(bytes32 id) external onlyManager {
    TracleStorage storage $ = _getTracleStorage();

    delete $.matrixVaultPriceConfigs[id];
    emit MatrixVaultPriceConfigUnset(id);
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _getStoredPrice(TracleStorage storage $, bytes32 id) internal view returns (Price memory) {
    require($.prices[id].updatedAt != 0, ITracle__InvalidPriceId(id));
    return $.prices[id];
  }

  function _getMatrixVaultPrice(TracleStorage storage $, IMatrixVault matrixVault, bytes32 underlyingPriceId)
    internal
    view
    returns (Price memory)
  {
    Price memory underlyingPrice = _getStoredPrice($, underlyingPriceId);
    uint208 price = SafeCast.toUint208(underlyingPrice.price * matrixVault.totalAssets() / matrixVault.totalSupply());
    return Price({ price: price, updatedAt: underlyingPrice.updatedAt });
  }
}
