// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { IERC20Snapshots } from '../../interfaces/twab/IERC20Snapshots.sol';
import { StdError } from '../../lib/StdError.sol';
import { ERC4626Snapshots } from '../../twab/ERC4626Snapshots.sol';
import { MatrixVaultStorageV1 } from './MatrixVaultStorageV1.sol';

/**
 * @title MatrixVault
 * @notice Base implementation of an MatrixVault
 */
abstract contract MatrixVault is MatrixVaultStorageV1, ERC4626Snapshots {
  using Math for uint256;

  function __MatrixVault_init(address assetManager_, IERC20Snapshots asset_, string memory name, string memory symbol)
    internal
  {
    if (bytes(name).length == 0 || bytes(symbol).length == 0) {
      name = string.concat('Mitosis ', asset_.name());
      symbol = string.concat('mi', asset_.symbol());
    }

    __ERC4626_init(asset_);
    __ERC20Snapshots_init(name, symbol);

    StorageV1 storage $ = _getStorageV1();

    _setAssetManager($, assetManager_);
  }

  // Mutative functions

  function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    require(assets <= maxAssets, ERC4626ExceededMaxDeposit(receiver, assets, maxAssets));

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares);

    return shares;
  }

  function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    require(shares <= maxShares, ERC4626ExceededMaxMint(receiver, shares, maxShares));

    uint256 assets = previewMint(shares);
    _deposit(_msgSender(), receiver, assets, shares);

    return assets;
  }

  function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyReclaimQueue($);

    uint256 maxAssets = maxWithdraw(owner);
    require(assets <= maxAssets, ERC4626ExceededMaxWithdraw(owner, assets, maxAssets));

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyReclaimQueue($);

    uint256 maxShares = maxRedeem(owner);
    require(shares <= maxShares, ERC4626ExceededMaxRedeem(owner, shares, maxShares));

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return assets;
  }
}
