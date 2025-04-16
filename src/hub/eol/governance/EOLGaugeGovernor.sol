// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IEOLGaugeGovernor } from '../../../interfaces/hub/eol/governance/IEOLGaugeGovernor.sol';
import { IEOLProtocolRegistry } from '../../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { IEOLVault } from '../../../interfaces/hub/eol/vault/IEOLVault.sol';
import { Arrays } from '../../../lib/Arrays.sol';
import { StdError } from '../../../lib/StdError.sol';
import { TWABSnapshotsUtils } from '../../../lib/TWABSnapshotsUtils.sol';
import { EOLGaugeGovernorStorageV1 } from './EOLGaugeGovernorStorageV1.sol';

contract EOLGaugeGovernor is IEOLGaugeGovernor, Ownable2StepUpgradeable, EOLGaugeGovernorStorageV1 {
  using EnumerableSet for EnumerableSet.AddressSet;
  using Arrays for uint256[];

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner, IEOLProtocolRegistry protocolRegistry_) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);

    StorageV1 storage $ = _getStorageV1();
    $.protocolRegistry = protocolRegistry_;
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function isGovernanceInitialized(address eolVault) external view returns (bool) {
    return _governance(_getStorageV1(), eolVault).eolVault != IEOLVault(address(0));
  }

  function epochPeriod(address eolVault) external view returns (uint32) {
    return _governance(_getStorageV1(), eolVault).epochPeriod;
  }

  function lastEpochId(address eolVault) external view returns (uint256) {
    return _governance(_getStorageV1(), eolVault).lastEpochId;
  }

  function epoch(address eolVault, uint256 epochId) external view returns (uint48 startsAt, uint48 endsAt) {
    Epoch storage epoch_ = _epoch(_governance(_getStorageV1(), eolVault), epochId);
    return (epoch_.startsAt, epoch_.endsAt);
  }

  function protocolIds(address eolVault, uint256 epochId, uint256 chainId) external view returns (uint256[] memory) {
    Governance storage gov = _governance(_getStorageV1(), eolVault);
    Epoch storage epoch_ = _epoch(gov, epochId);
    return epoch_.voteInfoByChainId[chainId].protocolIds;
  }

  function voters(address eolVault, uint256 chainId) external view returns (address[] memory) {
    Governance storage gov = _governance(_getStorageV1(), eolVault);
    return gov.totalVoteInfoByChainId[chainId].voters.values();
  }

  function voteResult(address eolVault, uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 gaugeSum, uint32[] memory gauges)
  {
    Governance storage gov = _governance(_getStorageV1(), eolVault);
    Epoch storage epoch_ = _epoch(gov, epochId);

    (bool exists, uint256 latestVotedEpochId) = _latestVotedEpochIdBefore(gov, epochId, chainId, account);
    if (!exists) return (false, 0, new uint32[](0));

    EpochVoteInfo storage latestVotedEpochVoteInfo = gov.epochs[latestVotedEpochId].voteInfoByChainId[chainId];
    uint256[] memory latestVotedProtocolIds = latestVotedEpochVoteInfo.protocolIds;
    uint32[] memory latestVotedGauges = latestVotedEpochVoteInfo.gaugesByAccount[account];

    uint256[] memory protocolIds_ = epoch_.voteInfoByChainId[chainId].protocolIds;
    gauges = new uint32[](protocolIds_.length);
    gaugeSum = 0;

    for (uint256 i = 0; i < protocolIds_.length; i++) {
      for (uint256 j = 0; j < latestVotedProtocolIds.length; j++) {
        if (protocolIds_[i] == latestVotedProtocolIds[j]) {
          gauges[i] = latestVotedGauges[j];
          gaugeSum += gauges[i];
          break;
        }
      }
    }

    return (true, gaugeSum, gauges);
  }

  //=========== NOTE: MUTATION FUNCTIONS ===========//

  function castVote(address eolVault, uint256 chainId, uint32[] memory gauges) external {
    StorageV1 storage $ = _getStorageV1();
    Governance storage gov = _governance($, eolVault);

    _moveToLatestEpoch(gov);

    Epoch storage epoch_ = _ongoingEpoch(gov);
    EpochVoteInfo storage epochVoteInfo = _getOrInitEpochVoteInfo($, gov, epoch_, chainId);

    require(gauges.length > 0, IEOLGaugeGovernor__ZeroGaugesLength());
    require(
      gauges.length == epochVoteInfo.protocolIds.length,
      IEOLGaugeGovernor__InvalidGaugesLength(gauges.length, epochVoteInfo.protocolIds.length)
    );
    require(_sum(gauges) == 100, IEOLGaugeGovernor__InvalidGaugesSum());

    epochVoteInfo.gaugesByAccount[_msgSender()] = gauges;

    TotalVoteInfo storage totalVoteInfo = gov.totalVoteInfoByChainId[chainId];
    totalVoteInfo.voters.add(_msgSender());

    uint256[] storage votedEpochIds = totalVoteInfo.votedEpochIdsByAccount[_msgSender()];
    uint256 votedEpochIdsLen = votedEpochIds.length;
    if (votedEpochIdsLen == 0 || votedEpochIds[votedEpochIdsLen - 1] < epoch_.id) {
      votedEpochIds.push(epoch_.id);
    }

    emit VoteCasted(eolVault, epoch_.id, chainId, _msgSender(), gauges);
  }

  function moveToLatestEpoch(address eolVault) external {
    Governance storage gov = _governance(_getStorageV1(), eolVault);
    _moveToLatestEpoch(gov);
  }

  function moveToNextEpochIfNeeded(address eolVault) external {
    Governance storage gov = _governance(_getStorageV1(), eolVault);
    _moveToNextEpochIfNeeded(gov);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initGovernance(address eolVault, uint32 epochPeriod_, uint48 startsAt) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();
    Governance storage gov = $.governances[eolVault];
    require(address(gov.eolVault) == address(0), IEOLGaugeGovernor__GovernanceAlreadyInitialized(eolVault));

    gov.eolVault = IEOLVault(eolVault);
    gov.epochPeriod = epochPeriod_;
    _moveToNextEpoch(gov, startsAt);
  }

  function setEpochPeriod(address eolVault, uint32 epochPeriod_) external onlyOwner {
    Governance storage gov = _governance(_getStorageV1(), eolVault);

    _moveToLatestEpoch(gov);
    gov.epochPeriod = epochPeriod_;

    emit EpochPeriodSet(epochPeriod_);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _governance(StorageV1 storage $, address eolVault) internal view returns (Governance storage) {
    Governance storage gov = $.governances[eolVault];
    require(address(gov.eolVault) != address(0), IEOLGaugeGovernor__GovernanceNotFound(eolVault));
    return gov;
  }

  function _epoch(Governance storage gov, uint256 epochId) internal view returns (Epoch storage) {
    Epoch storage epoch_ = gov.epochs[epochId];
    require(epoch_.id != 0, IEOLGaugeGovernor__EpochNotFound(address(gov.eolVault), epochId));
    return epoch_;
  }

  function _ongoingEpoch(Governance storage gov) internal view returns (Epoch storage) {
    Epoch storage epoch_ = _epoch(gov, gov.lastEpochId);
    uint48 currentTime = gov.eolVault.clock();

    require(
      currentTime >= epoch_.startsAt && currentTime < epoch_.endsAt,
      IEOLGaugeGovernor__EpochNotOngoing(address(gov.eolVault), epoch_.id)
    );

    return epoch_;
  }

  function _latestVotedEpochIdBefore(Governance storage gov, uint256 epochIdBefore, uint256 chainId, address account)
    internal
    view
    returns (bool exists, uint256 latestVotedEpochId)
  {
    uint256[] memory votedEpochIds = gov.totalVoteInfoByChainId[chainId].votedEpochIdsByAccount[account];
    uint256 upperBoundIdx = votedEpochIds.upperBoundMemory(epochIdBefore);
    if (upperBoundIdx == 0) return (false, 0);
    else return (true, votedEpochIds[upperBoundIdx - 1]);
  }

  function _moveToLatestEpoch(Governance storage gov) internal {
    uint48 currentTime = gov.eolVault.clock();
    Epoch storage epoch_ = _ongoingEpoch(gov);
    while (currentTime >= epoch_.endsAt) {
      epoch_ = _moveToNextEpoch(gov, epoch_.endsAt);
    }
  }

  function _moveToNextEpochIfNeeded(Governance storage gov) internal {
    uint48 currentTime = gov.eolVault.clock();
    Epoch storage epoch_ = _ongoingEpoch(gov);
    if (currentTime >= epoch_.endsAt) {
      _moveToNextEpoch(gov, epoch_.endsAt);
    }
  }

  function _moveToNextEpoch(Governance storage gov, uint48 startsAt) internal returns (Epoch storage) {
    uint256 epochId = ++gov.lastEpochId;

    Epoch storage epoch_ = gov.epochs[epochId];
    epoch_.id = epochId;
    epoch_.startsAt = startsAt;
    epoch_.endsAt = startsAt + gov.epochPeriod;

    emit EpochStarted(address(gov.eolVault), epoch_.id, epoch_.startsAt, epoch_.endsAt);

    return epoch_;
  }

  function _getOrInitEpochVoteInfo(StorageV1 storage $, Governance storage gov, Epoch storage epoch_, uint256 chainId)
    internal
    returns (EpochVoteInfo storage)
  {
    EpochVoteInfo storage voteInfo = epoch_.voteInfoByChainId[chainId];
    if (voteInfo.protocolIds.length == 0) {
      voteInfo.protocolIds = $.protocolRegistry.protocolIds(address(gov.eolVault), chainId);
      emit ProtocolIdsFetched(address(gov.eolVault), epoch_.id, chainId, voteInfo.protocolIds);
    }
    return voteInfo;
  }

  function _sum(uint32[] memory arr) internal pure returns (uint256 sum) {
    for (uint256 i = 0; i < arr.length; i++) {
      sum += arr[i];
    }
    return sum;
  }
}
