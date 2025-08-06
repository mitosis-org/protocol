// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { SafeERC20 } from '@oz/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@oz/utils/ReentrancyGuard.sol';

import { IMitosisVault } from '../interfaces/branch/IMitosisVault.sol';
import { IWrappedNativeToken } from '../interfaces/IWrappedNativeToken.sol';
import { StdError } from '../lib/StdError.sol';

contract MitosisVaultNativeDepositProxy is ReentrancyGuard {
  using SafeERC20 for IWrappedNativeToken;

  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  IWrappedNativeToken public immutable wrapped;
  IMitosisVault public immutable vault;

  constructor(IWrappedNativeToken wrapped_, IMitosisVault vault_) {
    wrapped = wrapped_;
    vault = vault_;
  }

  function deposit(address to, uint256 amount) external payable nonReentrant {
    require(msg.value >= amount, StdError.InvalidParameter('amount'));

    wrapped.deposit{ value: amount }();

    wrapped.forceApprove(address(vault), amount);
    vault.deposit{ value: msg.value - amount }(NATIVE_TOKEN, to, amount);
    wrapped.forceApprove(address(vault), 0);
  }

  function depositWithSupplyMatrix(address to, address hubMatrixVault, uint256 amount) external payable nonReentrant {
    require(msg.value >= amount, StdError.InvalidParameter('amount'));

    wrapped.deposit{ value: amount }();

    wrapped.forceApprove(address(vault), amount);
    vault.depositWithSupplyMatrix{ value: msg.value - amount }(NATIVE_TOKEN, to, hubMatrixVault, amount);
    wrapped.forceApprove(address(vault), 0);
  }
}
