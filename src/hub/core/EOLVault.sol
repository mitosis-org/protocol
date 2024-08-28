// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { Math } from '@oz-v5/utils/math/Math.sol';

import { IMitosisLedger } from '../../interfaces/hub/core/IMitosisLedger.sol';
import { IERC20TwabSnapshots } from '../../interfaces/twab/IERC20TwabSnapshots.sol';
import { ERC4626TwabSnapshots } from '../../twab/ERC4626TwabSnapshots.sol';
import { EOLVaultStorageV1 } from './storage/EOLVaultStorageV1.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLVault is ERC4626TwabSnapshots, EOLVaultStorageV1 {
  using Math for uint256;

  error EOLVault__AlreadyEolIdAssinged();
  error EOLVault__EolIdNotAssinged();

  constructor() {
    _disableInitializers();
  }

  function initialize(IERC20TwabSnapshots asset_, IMitosisLedger mitosisLedger_, address assetManager_)
    external
    initializer
  {
    string memory name = asset_.name();
    string memory symbol = asset_.symbol();
    _initialize(
      asset_,
      mitosisLedger_,
      assetManager_,
      string(abi.encodePacked('Mitosis ', name)),
      string(abi.encodePacked('mi', symbol))
    );
  }

  function initializeWithTokenMetadata(
    IERC20TwabSnapshots asset_,
    IMitosisLedger mitosisLedger_,
    address assetManager_,
    string memory name,
    string memory symbol
  ) external initializer {
    _initialize(asset_, mitosisLedger_, assetManager_, name, symbol);
  }

  function _initialize(
    IERC20TwabSnapshots asset_,
    IMitosisLedger mitosisLedger_,
    address assetManager_,
    string memory name,
    string memory symbol
  ) internal {
    __ERC4626_init(asset_);
    __ERC20_init(name, symbol);

    _getStorageV1().mitosisLedger = mitosisLedger_;

    // For AssetManager.settleLoss.
    //
    // note: There is no case where the maximum possible settleLoss is
    // greater than the actual amount of tokens available in the EOLVault.
    asset_.approve(assetManager_, type(uint256).max);
  }

  // View functions

  function eolId() external view returns (uint256) {
    return _getStorageV1().eolId;
  }

  // Mutative functions

  function assignEolId(uint256 eolId_) external {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyMitosisLedger($);
    _assertEolIdNotSet($);

    if ($.eolId != 0) revert EOLVault__AlreadyEolIdAssinged();
    $.eolId = eolId_;
  }

  function deposit(uint256 assets, address receiver) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertEolIdSet($);

    uint256 maxAssets = maxDeposit(receiver);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
    }

    uint256 shares = previewDeposit(assets);
    _optIn($, _msgSender(), receiver, assets, shares);

    return shares;
  }

  function mint(uint256 shares, address receiver) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertEolIdSet($);

    uint256 maxShares = maxMint(receiver);
    if (shares > maxShares) {
      revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
    }

    uint256 assets = previewMint(shares);
    _optIn($, _msgSender(), receiver, assets, shares);

    return assets;
  }

  // note: recordOptOutRequest, recordOptOutResolve, recordOptOutClaim are
  // called by OptOutQueue.

  function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertEolIdSet($);
    _assertOnlyOptOutQueue($);

    uint256 maxAssets = maxWithdraw(owner);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
    }

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
    StorageV1 storage $ = _getStorageV1();

    _assertEolIdSet($);
    _assertOnlyOptOutQueue($);

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
    $.mitosisLedger.recordOptIn($.eolId, shares);
  }

  function _assertOnlyMitosisLedger(StorageV1 storage $) internal view {
    if (_msgSender() != address($.mitosisLedger)) revert StdError.Unauthorized();
  }

  function _assertOnlyOptOutQueue(StorageV1 storage $) internal view {
    if (_msgSender() != $.mitosisLedger.optOutQueue()) revert StdError.Unauthorized();
  }

  function _assertEolIdSet(StorageV1 storage $) internal view {
    if ($.eolId == 0) revert EOLVault__EolIdNotAssinged();
  }

  function _assertEolIdNotSet(StorageV1 storage $) internal view {
    if ($.eolId != 0) revert EOLVault__AlreadyEolIdAssinged();
  }
}
