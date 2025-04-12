// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu/proxy/utils/UUPSUpgradeable.sol';
import { ContextUpgradeable } from '@ozu/utils/ContextUpgradeable.sol';

import { IMitosisVaultEntrypoint } from '../interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMitosisVaultEOL, EOLAction } from '../interfaces/branch/IMitosisVaultEOL.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { Pausable } from '../lib/Pausable.sol';
import { StdError } from '../lib/StdError.sol';

abstract contract MitosisVaultCore is Pausable, Ownable2StepUpgradeable, UUPSUpgradeable {
  function _deposit(address asset, address to, uint256 amount) internal virtual;

  function _assertAssetInitialized(address asset) internal view virtual;

  function entrypoint() public view virtual returns (address);

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function _authorizePause(address) internal view override onlyOwner { }

  function _msgSender() internal view override(Pausable, ContextUpgradeable) returns (address) {
    return super._msgSender();
  }
}
