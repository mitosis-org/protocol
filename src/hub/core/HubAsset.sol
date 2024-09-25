// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IVoteManager } from '../../interfaces/hub/core/IVoteManager.sol';
import { StdError } from '../../lib/StdError.sol';
import { ERC20TWABSnapshotsWithVote } from '../../twab/ERC20TWABSnapshotsWithVote.sol';

contract HubAsset is ERC20TWABSnapshotsWithVote {
  constructor() {
    _disableInitializers();
  }

  function initialize(IVoteManager voteManager, string memory name_, string memory symbol_) external initializer {
    __ERC20TWABSnapshotsWithVote_init(voteManager, name_, symbol_);
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

  function _getVotingUnits(address account) internal view override returns (uint256) {
    return balanceOf(account);
  }
}
