// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Ownable } from '@oz/access/Ownable.sol';
import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { Math } from '@oz/utils/math/Math.sol';
import { ReentrancyGuard } from '@oz/utils/ReentrancyGuard.sol';

import { ERC4626 } from '@solady/tokens/ERC4626.sol';

import { IMatrixVault } from '../../interfaces/hub/matrix/IMatrixVault.sol';
import { Pausable } from '../../lib/Pausable.sol';
import { StdError } from '../../lib/StdError.sol';
import { Versioned } from '../../lib/Versioned.sol';
import { MatrixVaultStorageV1 } from './MatrixVaultStorageV1.sol';

/**
 * @title MatrixVault
 * @notice Base implementation of an MatrixVault
 */
abstract contract MatrixVault is MatrixVaultStorageV1, ERC4626, Pausable, ReentrancyGuard, Versioned {
  using Math for uint256;

  modifier onlyOwner() {
    require(owner() == _msgSender(), StdError.Unauthorized());
    _;
  }

  function __MatrixVault_init(address assetManager_, IERC20Metadata asset_, string memory name_, string memory symbol_)
    internal
  {
    __Pausable_init();

    if (bytes(name_).length == 0 || bytes(symbol_).length == 0) {
      name_ = string.concat('Mitosis Matrix ', asset_.name());
      symbol_ = string.concat('ma', asset_.symbol());
    }

    StorageV1 storage $ = _getStorageV1();
    $.asset = address(asset_);
    $.name = name_;
    $.symbol = symbol_;

    (bool success, uint8 result) = _tryGetAssetDecimals(address(asset_));
    $.decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;

    _setAssetManager($, assetManager_);
  }

  function owner() public view returns (address) {
    return Ownable(address(_getStorageV1().assetManager)).owner();
  }

  function asset() public view override returns (address) {
    return _getStorageV1().asset;
  }

  function name() public view override returns (string memory) {
    return _getStorageV1().name;
  }

  function symbol() public view override returns (string memory) {
    return _getStorageV1().symbol;
  }

  function _underlyingDecimals() internal view override returns (uint8) {
    return _getStorageV1().decimals;
  }

  function _decimalsOffset() internal pure override returns (uint8) {
    return 6;
  }

  // Mutative functions

  function deposit(uint256 assets, address receiver)
    public
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (uint256)
  {
    uint256 maxAssets = maxDeposit(receiver);
    require(assets <= maxAssets, DepositMoreThanMax());

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares);

    return shares;
  }

  function mint(uint256 shares, address receiver) public virtual override nonReentrant whenNotPaused returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    require(shares <= maxShares, MintMoreThanMax());

    uint256 assets = previewMint(shares);
    _deposit(_msgSender(), receiver, assets, shares);

    return assets;
  }

  function withdraw(uint256 assets, address receiver, address owner_)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256)
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyReclaimQueue($);

    uint256 maxAssets = maxWithdraw(owner_);
    require(assets <= maxAssets, WithdrawMoreThanMax());

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner_, assets, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner_)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256)
  {
    StorageV1 storage $ = _getStorageV1();

    _assertOnlyReclaimQueue($);

    uint256 maxShares = maxRedeem(owner_);
    require(shares <= maxShares, RedeemMoreThanMax());

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner_, assets, shares);

    return assets;
  }

  // general overrides

  function _authorizePause(address) internal view override onlyOwner { }
}
