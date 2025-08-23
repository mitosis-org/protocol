// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20 } from '@oz/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz/token/ERC20/utils/SafeERC20.sol';

import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';
import { MitosisVault } from './MitosisVault.sol';
import { VLFStrategyExecutorMigration } from './strategy/VLFStrategyExecutorMigration.sol';

contract MitosisVaultMigration is MitosisVault {
  using SafeERC20 for IERC20;
  using ERC7201Utils for string;

  event MigrationInitiated(address hubVLFVault, uint256 migratedAmount);
  event VLFAssetsMigrated(address asset, address hubVLFVault, uint256 depositAndSupplyAmount, uint256 donationAmount);
  event VLFFetchedManually(address hubVLFVault, uint256 amount);

  struct MigrationStorageV1 {
    mapping(address hubVLFVault => uint256 unresolvedDepositAmount) unresolvedDepositAmountsByVLF;
    mapping(address hubVLFVault => uint256 unresolvedFetchAmount) unresolvedFetchAmountsByVLF;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisVaultMigration.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getMigrationStorageV1() internal view returns (MigrationStorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  function unresolvedDepositAmount(address hubVLFVault) external view returns (uint256) {
    return _getMigrationStorageV1().unresolvedDepositAmountsByVLF[hubVLFVault];
  }

  function unresolvedFetchAmount(address hubVLFVault) external view returns (uint256) {
    return _getMigrationStorageV1().unresolvedFetchAmountsByVLF[hubVLFVault];
  }

  function initiateMigration(address hubVLFVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);

    address strategyExecutor = $.vlfs[hubVLFVault].strategyExecutor;
    require(strategyExecutor != address(0), StdError.InvalidParameter('strategyExecutor'));

    uint256 migratedAmount = VLFStrategyExecutorMigration(payable(strategyExecutor)).manualSettle();

    MigrationStorageV1 storage $$ = _getMigrationStorageV1();
    $$.unresolvedDepositAmountsByVLF[hubVLFVault] += migratedAmount;
    $$.unresolvedFetchAmountsByVLF[hubVLFVault] += migratedAmount;

    emit MigrationInitiated(hubVLFVault, migratedAmount);
  }

  function migrateVLFAssets(
    address asset,
    address hubVLFVault,
    address depositAndSupplyTo,
    uint256 depositAndSupplyAmount,
    uint256 donationAmount,
    uint256 depositAndSupplyGasFee,
    uint256 donationGasFee
  ) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
    MigrationStorageV1 storage $$ = _getMigrationStorageV1();
    require(
      $$.unresolvedDepositAmountsByVLF[hubVLFVault] == depositAndSupplyAmount + donationAmount,
      StdError.InvalidParameter('depositAndSupplyAmount + donationAmount')
    );
    $$.unresolvedDepositAmountsByVLF[hubVLFVault] = 0;

    require(depositAndSupplyTo != address(0), StdError.ZeroAddress('depositAndSupplyTo'));
    require(depositAndSupplyAmount != 0, StdError.ZeroAmount());
    require(donationAmount != 0, StdError.ZeroAmount());
    require(msg.value == depositAndSupplyGasFee + donationGasFee, StdError.InvalidParameter('msg.value'));

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertAssetInitialized(asset);
    _assertVLFInitialized($, hubVLFVault);
    require(asset == $.vlfs[hubVLFVault].asset, IMitosisVaultVLF__InvalidVLF(hubVLFVault, asset));

    // Step 1. Mint VLF Asset to a given address
    if (depositAndSupplyAmount > 0) {
      _entrypoint().depositWithSupplyVLF{ value: depositAndSupplyGasFee }(
        asset, depositAndSupplyTo, hubVLFVault, depositAndSupplyAmount, _msgSender()
      );
      emit VLFDepositedWithSupply(asset, depositAndSupplyTo, hubVLFVault, depositAndSupplyAmount);
    }

    // Step 2. Donate assets to a VLF Vault to adjust ratio of VLF Vault
    if (donationAmount > 0) {
      _entrypoint().deposit{ value: donationGasFee }(asset, hubVLFVault, donationAmount, _msgSender());
      emit Deposited(asset, hubVLFVault, donationAmount);
    }

    emit VLFAssetsMigrated(asset, hubVLFVault, depositAndSupplyAmount, donationAmount);
  }

  function manualFetchVLF(address hubVLFVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
    MigrationStorageV1 storage $$ = _getMigrationStorageV1();
    uint256 amount = $$.unresolvedFetchAmountsByVLF[hubVLFVault];
    require(amount > 0, StdError.InvalidParameter('amount'));
    $$.unresolvedFetchAmountsByVLF[hubVLFVault] = 0;

    VLFStorageV1 storage $ = _getVLFStorageV1();
    _assertVLFInitialized($, hubVLFVault);

    $.vlfs[hubVLFVault].availableLiquidity -= amount;
    emit VLFFetched(hubVLFVault, amount);

    emit VLFFetchedManually(hubVLFVault, amount);
  }
}
