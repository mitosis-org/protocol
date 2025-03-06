// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC5805 } from '@oz-v5/interfaces/IERC5805.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { IValidatorStaking } from '../interfaces/hub/validator/IValidatorStaking.sol';
import { StdError } from '../lib/StdError.sol';

/// @title GovMITOProxy
/// @notice VotingPower proxy that combines GovMITO + ValidatorStaking(GovMITO)
contract GovMITOProxy is IERC5805, UUPSUpgradeable, Ownable2StepUpgradeable {
  using SafeCast for uint256;

  IGovMITO private immutable _govMITO;
  IValidatorStaking private immutable _govMITOStaking;

  constructor(IGovMITO govMITO_, IValidatorStaking govMITOStaking_) {
    _disableInitializers();

    _govMITO = govMITO_;
    _govMITOStaking = govMITOStaking_;
  }

  function initialize(address initialOwner) external initializer {
    __Ownable2Step_init();
    __Ownable_init(initialOwner);
  }

  function clock() public view returns (uint48) {
    return Time.timestamp();
  }

  function CLOCK_MODE() external pure returns (string memory) {
    return 'mode=timestamp';
  }

  function getVotes(address account) external view returns (uint256) {
    return _govMITO.getVotes(account) + _govMITOStaking.stakerTotal(account, clock());
  }

  function getPastVotes(address account, uint256 timestamp) external view returns (uint256) {
    return _govMITO.getPastVotes(account, timestamp) + _govMITOStaking.stakerTotal(account, timestamp.toUint48());
  }

  function getPastTotalSupply(uint256 timestamp) external view returns (uint256) {
    return _govMITO.getPastTotalSupply(timestamp) + _govMITOStaking.totalStaked(timestamp.toUint48());
  }

  function delegates(address account) external view returns (address) {
    return _govMITO.delegates(account);
  }

  function delegate(address) external pure {
    revert StdError.NotSupported();
  }

  function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) external pure {
    revert StdError.NotSupported();
  }

  // ============================ NOTE: UUPS OVERRIDES ============================ //

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
