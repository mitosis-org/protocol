// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IERC20Metadata } from '@oz/token/ERC20/extensions/IERC20Metadata.sol';
import { SafeERC20 } from '@oz/token/ERC20/utils/SafeERC20.sol';
import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';

import { IReclaimQueueCollector } from '../interfaces/hub/IReclaimQueueCollector.sol';
import { StdError } from '../lib/StdError.sol';

contract ReclaimQueueCollector is Ownable2StepUpgradeable, UUPSUpgradeable, IReclaimQueueCollector {
  using SafeERC20 for IERC20Metadata;

  address public immutable reclaimQueue;

  constructor(address reclaimQueue_) {
    _disableInitializers();

    reclaimQueue = reclaimQueue_;
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
  }

  function collect(address vault, address asset, uint256 collected) external override {
    require(_msgSender() == reclaimQueue, StdError.Unauthorized());

    IERC20Metadata(asset).safeTransferFrom(_msgSender(), address(this), collected);

    // add custom logic here. default behavior is to transfer the asset to the vault
    IERC20Metadata(asset).safeTransfer(vault, collected);

    emit Collected(vault, asset, collected);
  }

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
