// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';

contract MockMitosisVaultEntrypoint is IMitosisVaultEntrypoint {
  function vault() external view returns (IMitosisVault) { }

  function mitosisDomain() external view returns (uint32) { }

  function mitosisAddr() external view returns (bytes32) { }

  function quoteDeposit(address asset, address to, uint256 amount) external view returns (uint256) { }

  function quoteDepositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount)
    external
    view
    returns (uint256)
  { }

  function quoteDeallocateVLF(address hubVLF, uint256 amount) external view returns (uint256) { }

  function quoteSettleVLFYield(address hubVLF, uint256 amount) external view returns (uint256) { }

  function quoteSettleVLFLoss(address hubVLF, uint256 amount) external view returns (uint256) { }

  function quoteSettleVLFExtraRewards(address hubVLF, address reward, uint256 amount) external view returns (uint256) { }

  function deposit(address asset, address to, uint256 amount) external payable { }

  function depositWithSupplyVLF(address asset, address to, address hubVLF, uint256 amount) external payable { }

  function deallocateVLF(address hubVLF, uint256 amount) external payable { }

  function settleVLFYield(address hubVLF, uint256 amount) external payable { }

  function settleVLFLoss(address hubVLF, uint256 amount) external payable { }

  function settleVLFExtraRewards(address hubVLF, address reward, uint256 amount) external payable { }
}
