// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { AssetAction, EOLAction } from '../../interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IStrategyExecutor } from '../../interfaces/branch/strategy/IStrategyExecutor.sol';
import { IMitosisVaultStorageV1 } from '../../interfaces/branch/IMitosisVault.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

abstract contract MitosisVaultStorageV1 is IMitosisVaultStorageV1 {
  using ERC7201Utils for string;

  struct AssetInfo {
    bool initialized;
    mapping(AssetAction => bool) isHalted; // TODO(thai): consider better ACL management (e.g. similar to solmate's way)
  }

  struct EOLInfo {
    bool initialized;
    address asset;
    address strategyExecutor;
    uint256 availableEOL;
    mapping(EOLAction => bool) isHalted;
  }

  struct StorageV1 {
    IMitosisVaultEntrypoint entrypoint;
    mapping(address asset => AssetInfo) assets;
    mapping(address hubEOLVault => EOLInfo) eols;
  }

  string private constant _NAMESPACE = 'mitosis.storage.MitosisVaultStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _setEntrypoint(IMitosisVaultEntrypoint entrypoint) internal {
    _getStorageV1().entrypoint = entrypoint;
    emit EntrypointSet(address(entrypoint));
  }

  function _setStrategyExecutor(StorageV1 storage $, address hubEOLVault, address strategyExecutor) internal {
    EOLInfo storage eolInfo = $.eols[hubEOLVault];

    if (eolInfo.strategyExecutor != address(0)) {
      // NOTE: no way to check if every extra rewards are settled.
      bool drained = IStrategyExecutor(eolInfo.strategyExecutor).totalBalance() == 0
        && IStrategyExecutor(eolInfo.strategyExecutor).lastSettledBalance() == 0;

      require(drained, IMitosisVaultStorageV1__StrategyExecutorNotDrained(hubEOLVault, eolInfo.strategyExecutor));
    }

    require(
      hubEOLVault == IStrategyExecutor(strategyExecutor).hubEOLVault(),
      StdError.InvalidId('strategyExecutor.hubEOLVault')
    );
    require(
      address(this) == address(IStrategyExecutor(strategyExecutor).vault()),
      StdError.InvalidAddress('strategyExecutor.vault')
    );
    require(
      eolInfo.asset == address(IStrategyExecutor(strategyExecutor).asset()),
      StdError.InvalidAddress('strategyExecutor.asset')
    );

    eolInfo.strategyExecutor = strategyExecutor;
    emit StrategyExecutorSet(hubEOLVault, strategyExecutor);
  }

  function _haltAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = true;
    emit AssetHalted(asset, action);
  }

  function _resumeAsset(StorageV1 storage $, address asset, AssetAction action) internal {
    $.assets[asset].isHalted[action] = false;
    emit AssetResumed(asset, action);
  }

  function _haltEOL(StorageV1 storage $, address hubEOLVault, EOLAction action) internal {
    $.eols[hubEOLVault].isHalted[action] = true;
    emit EOLHalted(hubEOLVault, action);
  }

  function _resumeEOL(StorageV1 storage $, address hubEOLVault, EOLAction action) internal {
    $.eols[hubEOLVault].isHalted[action] = false;
    emit EOLResumed(hubEOLVault, action);
  }
}
