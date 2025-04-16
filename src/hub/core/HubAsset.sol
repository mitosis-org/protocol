// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { StdError } from '../../lib/StdError.sol';
import { ERC20TWABSnapshots } from '../../twab/ERC20TWABSnapshots.sol';

contract HubAsset is ERC20TWABSnapshots {
  constructor() {
    _disableInitializers();
  }

  function initialize(address delegationRegistry_, string memory name_, string memory symbol_) external initializer {
    __ERC20TWABSnapshots_init(delegationRegistry_, name_, symbol_);
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
