// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';

contract MockMitosisVaultEntrypoint is IMitosisVaultEntrypoint {
  function vault() external view returns (IMitosisVault vault_) { }

  function mitosisDomain() external view returns (uint32 mitosisDomain_) { }

  function mitosisAddr() external view returns (bytes32 mitosisAddr_) { }

  function deposit(address asset, address to, uint256 amount) external { }

  function depositWithOptIn(address asset, address to, address hubEOLVault, uint256 amount) external { }

  function deallocateEOL(address hubEOLVault, uint256 amount) external { }

  function settleYield(address hubEOLVault, uint256 amount) external { }

  function settleLoss(address hubEOLVault, uint256 amount) external { }

  function settleExtraRewards(address hubEOLVault, address reward, uint256 amount) external { }
}
