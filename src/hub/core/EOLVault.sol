// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';

import { EOLVaultStorageV1 } from './storage/EOLVaultStorageV1.sol';
import { ERC4626TwabSnapshots } from '../../twab/ERC4626TwabSnapshots.sol';
import { IEOLVault } from '../../interfaces/hub/core/IEOLVault.sol';
import { IERC20TwabSnapshots } from '../../interfaces/twab/IERC20TwabSnapshots.sol';
import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLVault is IEOLVault, EOLVaultStorageV1, ERC4626TwabSnapshots {
  using Math for uint256;

  error EOLVault__EolIdNotSet();

  constructor() {
    _disableInitializers();
  }

  function initialize(
    IERC20TwabSnapshots asset_,
    IMitosisLedger mitosisLedger_,
    address assetManager_,
    string memory name,
    string memory symbol
  ) external initializer {
    if (bytes(name).length == 0 || bytes(symbol).length == 0) {
      name = string.concat('Mitosis', asset_.name());
      symbol = string.concat('mi', asset_.symbol());
    }

    __ERC4626_init(asset_);
    __ERC20_init(name, symbol);
    _getStorageV1().mitosisLedger = mitosisLedger_;
  }

  // Mutative functions

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
    }

    uint256 shares = previewDeposit(assets);
    _optIn(_getStorageV1(), _msgSender(), receiver, assets, shares);

    return shares;
  }

  function mint(uint256 shares, address receiver) public override returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    if (shares > maxShares) {
      revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
    }

    uint256 assets = previewMint(shares);
    _optIn(_getStorageV1(), _msgSender(), receiver, assets, shares);

    return assets;
  }

  // note: recordOptOutRequest, recordOptOutResolve, recordOptOutClaim are
  // called by OptOutQueue.

  function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
    _assertOnlyOptOutQueue(_getStorageV1());

    uint256 maxAssets = maxWithdraw(owner);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
    }

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
    _assertOnlyOptOutQueue(_getStorageV1());

    uint256 maxShares = maxRedeem(owner);
    if (shares > maxShares) {
      revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
    }

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return assets;
  }

  function _optIn(StorageV1 storage $, address caller, address receiver, uint256 assets, uint256 shares) internal {
    _deposit(caller, receiver, assets, shares);
    $.mitosisLedger.recordOptIn(address(this), shares);
  }

  function _assertOnlyMitosisLedger(StorageV1 storage $) internal view {
    if (_msgSender() != address($.mitosisLedger)) revert StdError.Unauthorized();
  }

  function _assertOnlyOptOutQueue(StorageV1 storage $) internal view {
    // note: this is temporary implementation. we have to store the OptOutQueue address at more suitable place.
    if (_msgSender() != $.mitosisLedger.optOutQueue()) revert StdError.Unauthorized();
  }
}
