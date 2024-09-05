// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { StdError } from '../../lib/StdError.sol';
import { ERC20TwabSnapshots } from '../../twab/ERC20TwabSnapshots.sol';

contract HubAsset is ERC20TwabSnapshots {
  constructor() {
    _disableInitializers();
  }

  function initialize(string memory name_, string memory symbol_) external initializer {
    __ERC20_init(name_, symbol_);
  }

  modifier onlyHubAssetMintable() {
    // TODO(ray): When introduce RoleManagerContract, fill it.
    //
    // HubAssetMintable address: AssetManager
    _;
  }

  modifier onlyHubAssetBurnable() {
    // TODO(ray): When introduce RoleManagerContract, fill it.
    //
    // HubAssetBurnable address: AssetManager
    _;
  }

  function mint(address account, uint256 value) external onlyHubAssetMintable {
    _mint(account, value);
  }

  function burn(address account, uint256 value) external onlyHubAssetBurnable {
    _burn(account, value);
  }
}
