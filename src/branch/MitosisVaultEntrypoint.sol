// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PausableUpgradeable } from '@ozu-v5/utils/PausableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IMitosisVaultEntrypoint } from '@src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IMitosisVault } from '@src/interfaces/branch/IMitosisVault.sol';

// TODO(wip):

contract MitosisVaultEntrypoint is IMitosisVaultEntrypoint, PausableUpgradeable, Ownable2StepUpgradeable {
  IMitosisVault private _vault;

  constructor(address mailbox) initializer { }

  function initialize(address owner_, address vault_) public initializer {
    __Pausable_init();
    __Ownable2Step_init();
    _transferOwnership(owner_);

    _vault = IMitosisVault(vault_);
  }

  function vault() external view returns (IMitosisVault vault_) {
    return _vault;
  }

  function deposit(address asset, address to, uint256 amount) external { }

  function deallocateEOL(address asset, uint256 amount) external { }

  function settleYield(address asset, uint256 amount) external { }

  function settleLoss(address asset, uint256 amount) external { }

  function settleExtraRewards(address asset, address reward, uint256 amount) external { }

  //=========== NOTE: HANDLER FUNCTIONS ===========//

  function _handle(uint32 _origin, bytes32 _sender, bytes calldata _message) internal { }
}
