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

    StorageV1 storage $ = _getStorageV1();
    $.mitosisLedger = mitosisLedger_;
    $.assetManager = assetManager_; // EOLVault 에서 AssetManager 를 알아야 하는게 좀 그러네. 근데 AssetManager 가 EOLVault 의 ratio 를 관리하는 개념이니까 또 그리 문제가 될까 싶기도 하고.
  }

  modifier eolAssinged() {
    if (_getStorageV1().eolId == 0) revert('temp');
    _;
  }

  modifier onlyOptOutQueue() {
    // 근데 교체할 떄, 이전 Queeue 에 남아있는 것들이 withdraw, redeem 을 호출할 수 있어야 하지 않을까? 아니면 일단 halt 하고 모든 request 가
    // 끝났을 때 교체해도 되고.
    if (_msgSender() != _getStorageV1().mitosisLedger.optOutQueue()) revert StdError.Unauthorized();
    _;
  }

  function assignEolId(uint256 eolId_) external {
    StorageV1 storage $ = _getStorageV1();
    if (_msgSender() != address($.mitosisLedger)) revert StdError.Unauthorized();
    if ($.eolId != 0) revert('already set');
    $.eolId = eolId_;
  }

  function deposit(uint256 assets, address receiver) public override eolAssinged returns (uint256) {
    uint256 maxAssets = maxDeposit(receiver);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
    }

    uint256 shares = previewDeposit(assets);
    _deposit(_msgSender(), receiver, assets, shares);

    _optIn(_getStorageV1(), assets, shares);

    return shares;
  }

  function mint(uint256 shares, address receiver) public override eolAssinged returns (uint256) {
    uint256 maxShares = maxMint(receiver);
    if (shares > maxShares) {
      revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
    }

    uint256 assets = previewMint(shares);
    _deposit(_msgSender(), receiver, assets, shares);

    _optIn(_getStorageV1(), assets, shares);

    return assets;
  }

  // naming
  function _optIn(StorageV1 storage $, uint256 assets, uint256 shares) internal {
    IERC20 asset = IERC20(asset());
    asset.approve($.assetManager, asset.allowance(address(this), $.assetManager) + assets);
    $.mitosisLedger.recordOptIn($.eolId, shares);
  }

  // mitosisLedger.recordOptOutRequest(eolId, amount);
  // mitosisLedger.recordOptOutResolve(eolId, amount);
  // mitosisLedger.recordOptOutClaim(eolId, amount);
  //
  // 위 세 개는 OptOutQueue 에서 호출해준다.

  // OptOutRequest 가 resolve 될 때 호출될 메서드.
  //
  // loss 가 발생될 때 AssetMaanger 가 burn 을 해주는 allowance 를 줄인다는 것인데, loss > allowance 인 케이스가 발생하지는 않을까?
  // --> 발생하지 않음. Resolve 가 되었다는 것은, Branch 체인의 DeFi 에서 이미 출금이 되었다는 것을 의미하기 때문에...
  //
  // 근데 만약 Resolved -> Claimable 사이에도 loss 를 적용시킨다 해도, 위 방법이 유효할까?
  // loss 는 ratio 를 보고 알아서 적용시키면 됨. 여기서는 loss < allowance 만 신경쓰면 된다.
  //

  // 아... 아니 애초에 이런 작업을 안 해줘도 loss > allowance 인 경우가 존재할까?
  // 이거부터 확인.
  function reduceAssetManagerAllowance(uint256 value) external eolAssinged onlyOptOutQueue {
    IERC20 asset = IERC20(asset());
    address assetManager = _getStorageV1().assetManager;
    asset.approve(assetManager, asset.allowance(address(this), assetManager) - value);
  }

  function withdraw(uint256 assets, address receiver, address owner)
    public
    override
    eolAssinged
    onlyOptOutQueue
    returns (uint256)
  {
    uint256 maxAssets = maxWithdraw(owner);
    if (assets > maxAssets) {
      revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
    }

    uint256 shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner)
    public
    override
    eolAssinged
    onlyOptOutQueue
    returns (uint256)
  {
    uint256 maxShares = maxRedeem(owner);
    if (shares > maxShares) {
      revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
    }

    uint256 assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return assets;
  }
}
