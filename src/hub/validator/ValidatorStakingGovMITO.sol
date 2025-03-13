// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IConsensusValidatorEntrypoint } from '../../interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { IEpochFeeder } from '../../interfaces/hub/validator/IEpochFeeder.sol';
import { IValidatorManager } from '../../interfaces/hub/validator/IValidatorManager.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { ValidatorStaking } from './ValidatorStaking.sol';

contract ValidatorStakingGovMITO is ValidatorStaking {
  constructor(
    address baseAsset_,
    IEpochFeeder epochFeeder_,
    IValidatorManager manager_,
    IConsensusValidatorEntrypoint entrypoint_
  ) ValidatorStaking(baseAsset_, epochFeeder_, manager_, entrypoint_) { }

  function stake(address valAddr, address recipient, uint256 amount) public payable override {
    super.stake(valAddr, recipient, amount);
    IGovMITO(baseAsset()).notifyProxiedDeposit(_msgSender(), amount);
  }

  function requestUnstake(address valAddr, address receiver, uint256 amount) public override returns (uint256) {
    uint256 reqId = super.requestUnstake(valAddr, receiver, amount);
    if (_msgSender() != receiver) {
      IGovMITO(baseAsset()).notifyProxiedWithdraw(_msgSender(), amount);
      IGovMITO(baseAsset()).notifyProxiedDeposit(receiver, amount);
    }
    return reqId;
  }

  function claimUnstake(address valAddr, address receiver) public override returns (uint256) {
    uint256 claimed = super.claimUnstake(valAddr, receiver);
    IGovMITO(baseAsset()).notifyProxiedWithdraw(_msgSender(), claimed);
    return claimed;
  }
}
