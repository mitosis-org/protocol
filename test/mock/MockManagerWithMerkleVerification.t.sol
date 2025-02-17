// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IStrategyExecutor } from '../../src/interfaces/branch/strategy/IStrategyExecutor.sol';
import { IManagerWithMerkleVerification } from
  '../../src/interfaces/branch/strategy/manager/IManagerWithMerkleVerification.sol';

contract MockManagerWithMerkleVerification is IManagerWithMerkleVerification {
  mapping(address protocolVault => IStrategyExecutor) _strategyExecutors;

  function strategyExecutor(address protocolVault) external view returns (address) {
    return address(_strategyExecutors[protocolVault]);
  }

  function setStrategyExecutor(address protocolVault, address strategyExecutor_) external {
    _strategyExecutors[protocolVault] = IStrategyExecutor(strategyExecutor_);
  }

  function manageRoot(address, address strategist) external view returns (bytes32) { }

  function setManageRoot(address, address strategist, bytes32 _manageRoot) external { }

  function manageVaultWithMerkleVerification(
    address hubMatrixVault,
    bytes32[][] calldata,
    address[] calldata,
    address[] calldata targets,
    bytes[] calldata targetData,
    uint256[] calldata values
  ) external {
    for (uint256 i = 0; i < targets.length; i++) {
      _strategyExecutors[hubMatrixVault].execute(targets[i], targetData[i], values[i]);
    }
  }
}
