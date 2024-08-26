// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20TwabSnapshots } from '../../twab/ERC20TwabSnapshots.sol';
import { StdError } from '../../lib/StdError.sol';

contract HubAsset is ERC20TwabSnapshots {
  constructor() {
    _disableInitializers();
  }

  function initialize(string memory name_, string memory symbol_) external initializer {
    __ERC20_init(name_, symbol_);
  }

  modifier onlyHubAssetMintable() {
    // TODO(ray): When introduce RoleManagerContract, fill it. Or storing AssetManager to HubAssetStorageV1.
    //
    // HubAssetMintable address: AssetManager
    _;
  }

  function mint(address account, uint256 value) external onlyHubAssetMintable {
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
