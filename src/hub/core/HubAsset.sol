// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { HubAssetStorageV1 } from './storage/HubAssetStorageV1.sol';
import { ERC20TwabSnapshots } from '../../twab/ERC20TwabSnapshots.sol';
import { StdError } from '../../lib/StdError.sol';

contract HubAsset is ERC20TwabSnapshots, HubAssetStorageV1 {
  constructor() {
    _disableInitializers();
  }

  function initialize(address assetManager_, string memory name_, string memory symbol_) external initializer {
    __ERC20_init(name_, symbol_);
    _getStorageV1().assetManager = assetManager_;
  }

  modifier onlyMintable() {
  // TODO(ray): When introduce RoleManagerContract, fill it.
  //
  // Mintable address: AssetManager
    _;
  }

  function mint(address account, uint256 value) external onlyMintable {
    _mint(account, value);
  }

  function burn(uint256 value) external {
    _burn(_msgSender(), value);
  }

  function burnFrom(address account, uint256 value) external {
    _spendAllowance(account, _msgSender(), value);
    _burn(account, value);
  }
}
