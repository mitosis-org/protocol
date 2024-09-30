// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@oz-v5/token/ERC20/utils/SafeERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { IHubAsset } from '../../interfaces/hub/core/IHubAsset.sol';
import { IEOLVault } from '../../interfaces/hub/eol/IEOLVault.sol';
import { IERC20TWABSnapshots } from '../../interfaces/twab/IERC20TWABSnapshots.sol';
import { StdError } from '../../lib/StdError.sol';
import { ERC4626TWABSnapshots } from '../../twab/ERC4626TWABSnapshots.sol';
import { EOLVaultStorageV1 } from './EOLVaultStorageV1.sol';

contract EOLVault is EOLVaultStorageV1, ERC4626TWABSnapshots {
  using Math for uint256;
  using SafeERC20 for IERC20;

  error EOLVault__ExceededMaxLoss(uint256 loss, uint256 maxLoss);
  error EOLVault__ExceededMaxClaim(uint256 assets, uint256 maxPendingAssets);

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address delegationRegistry_,
    address rewardManager_,
    address assetManager_,
    IERC20TWABSnapshots asset_,
    string memory name,
    string memory symbol
  ) external initializer {
    if (bytes(name).length == 0 || bytes(symbol).length == 0) {
      name = string.concat('Mitosis', asset_.name());
      symbol = string.concat('mi', asset_.symbol());
    }

    __ERC4626_init(asset_);
    __ERC20TWABSnapshots_init(delegationRegistry_, name, symbol);

    StorageV1 storage $ = _getStorageV1();

    _setRewardManager($, rewardManager_);
    _setAssetManager($, assetManager_);
  }

  // =========================== NOTE: VIEW FUNCTIONS =========================== //

  function totalAssets() public view override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    return $.totalAssets;
  }

  // Mutative functions (ERC4626 interface)

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    require(assets <= maxAssets, ERC4626ExceededMaxDeposit(receiver, assets, maxAssets));

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares);
    _getStorageV1().totalAssets += assets;

    return shares;
  }

  function mint(uint256 shares, address receiver) public override returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    require(shares <= maxShares, ERC4626ExceededMaxMint(receiver, shares, maxShares));

    uint256 assets = previewMint(shares);
    _deposit(_msgSender(), receiver, assets, shares);
    _getStorageV1().totalAssets += assets;

    return assets;
  }

  /**
   * @dev opt-out queue only
   */
  function withdraw(uint256 assets, address, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyOptOutQueue($);

    uint256 maxAssets = maxWithdraw(owner);
    require(assets <= maxAssets, ERC4626ExceededMaxWithdraw(owner, assets, maxAssets));

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), address(0), owner, assets, shares);

    return shares;
  }

  /**
   * @dev opt-out queue only
   */
  function redeem(uint256 shares, address, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyOptOutQueue($);

    uint256 maxShares = maxRedeem(owner);
    require(shares <= maxShares, ERC4626ExceededMaxRedeem(owner, shares, maxShares));

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), address(0), owner, assets, shares);

    return assets;
  }

  /**
   * @dev opt-out queue only
   */
  function claim(uint256 assets, address receiver) external returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyOptOutQueue($);

    IHubAsset(asset()).mint(receiver, assets);

    emit IEOLVault.PendingAssetsClaimed(receiver, assets);

    return assets;
  }

  /**
   * @dev opt-out queue and reward manager only
   * - opt-out queue: return loss from opt out queue
   * - reward manager: settle yield from the branch vault
   */
  function settleYield(uint256 yield) external {
    StorageV1 storage $ = _getStorageV1();

    address caller = _msgSender();
    require(caller == $.assetManager.optOutQueue() || caller == address($.rewardManager), StdError.Unauthorized());

    $.totalAssets += yield;

    emit IEOLVault.YieldSettled(yield);
  }

  /**
   * @dev opt-out queue and reward manager only
   */
  function settleLoss(uint256 loss) external {
    StorageV1 storage $ = _getStorageV1();

    address caller = _msgSender();
    require(caller == $.assetManager.optOutQueue() || caller == address($.rewardManager), StdError.Unauthorized());

    uint256 maxLoss = $.totalAssets;
    require(loss <= maxLoss, EOLVault__ExceededMaxLoss(loss, maxLoss));

    $.totalAssets -= loss;

    emit IEOLVault.LossSettled(loss);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  /**
   * @dev overrides ERC4626's `_withdraw` to not to transfer (mint) assets to the receiver
   */
  function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
    if (caller != owner) _spendAllowance(owner, caller, shares);

    _burn(owner, shares);

    _getStorageV1().totalAssets -= assets;

    emit Withdraw(caller, receiver, owner, assets, shares);
  }
}
