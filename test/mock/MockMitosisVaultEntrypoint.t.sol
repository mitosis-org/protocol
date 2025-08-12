// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { IMitosisVault } from '../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';

contract MockMitosisVaultEntrypoint is IMitosisVaultEntrypoint {
  mapping(bytes4 => uint256) public gas;

  function setGas(bytes4 selector, uint256 gas_) external {
    gas[selector] = gas_;
  }

  function vault() external view returns (IMitosisVault) { }

  function mitosisDomain() external view returns (uint32) { }

  function mitosisAddr() external view returns (bytes32) { }

  function quoteDeposit(address, address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function quoteDepositWithSupplyVLF(address, address, address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function quoteDeallocateVLF(address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function quoteSettleVLFYield(address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function quoteSettleVLFLoss(address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function quoteSettleVLFExtraRewards(address, address, uint256) external view returns (uint256) {
    return gas[msg.sig];
  }

  function deposit(address, address, uint256) external payable { }

  function depositWithSupplyVLF(address, address, address, uint256) external payable { }

  function deallocateVLF(address, uint256) external payable { }

  function settleVLFYield(address, uint256) external payable { }

  function settleVLFLoss(address, uint256) external payable { }

  function settleVLFExtraRewards(address, address, uint256) external payable { }
}
