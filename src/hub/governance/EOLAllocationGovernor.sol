// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IEOLProtocolRegistry } from '../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { IEOLAllocationGovernor } from '../../interfaces/hub/governance/IEOLAllocationGovernor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { Arrays } from '../../lib/Arrays.sol';
import { StdError } from '../../lib/StdError.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';
import {
  EOLAllocationGovernorStorageV1, Epoch, EpochVoteInfo, TotalVoteInfo
} from './EOLAllocationGovernorStorageV1.sol';

// TODO(thai): add more view and ownable functions

contract EOLAllocationGovernor is IEOLAllocationGovernor, Ownable2StepUpgradeable, EOLAllocationGovernorStorageV1 {
  using TWABSnapshotsUtils for ITWABSnapshots;
  using EnumerableSet for EnumerableSet.AddressSet;
  using Arrays for uint256[];

  event EpochStarted(uint256 indexed epochId, uint48 startsAt, uint48 endsAt);
  event ProtocolIdsFetched(uint256 indexed epochId, uint256 indexed chainId, uint256[] protocolIds);
  event VoteCasted(uint256 indexed epochId, uint256 indexed chainId, address indexed account, uint32[] gauges);

  event EpochPeriodSet(uint32 epochPeriod);

  error EOLAllocationGovernor__EpochNotFound(uint256 epochId);
  error EOLAllocationGovernor__EpochNotOngoing(uint256 epochId);

  error EOLAllocationGovernor__ZeroGaugesLength();
  error EOLAllocationGovernor__InvalidGaugesLength(uint256 actual, uint256 expected);
  error EOLAllocationGovernor__InvalidGaugesSum();

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address owner,
    IEOLProtocolRegistry protocolRegistry_,
    ITWABSnapshots eolAsset,
    uint32 twabPeriod,
    uint32 epochPeriod,
    uint48 startsAt
  ) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);

    StorageV1 storage $ = _getStorageV1();
    $.protocolRegistry = protocolRegistry_;
    $.eolAsset = eolAsset;
    $.twabPeriod = twabPeriod;
    $.epochPeriod = epochPeriod;

    _moveToNextEpoch($, startsAt);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

  function voters(uint256 chainId) external view returns (address[] memory) {
    StorageV1 storage $ = _getStorageV1();
    return $.totalVoteInfoByChainId[chainId].voters.values();
  }

  function lastEpochId() external view returns (uint256) {
    return _getStorageV1().lastEpochId;
  }

  function totalVotingPower(uint256 epochId) external view returns (uint256) {
    StorageV1 storage $ = _getStorageV1();
    Epoch storage epoch = _epoch($, epochId);
    return _getTotalVotingPower($, epoch);
  }

  function protocolIds(uint256 epochId, uint256 chainId) external view returns (uint256[] memory) {
    StorageV1 storage $ = _getStorageV1();
    Epoch storage epoch = _epoch($, epochId);
    return epoch.voteInfoByChainId[chainId].protocolIds;
  }

  function voteResult(uint256 epochId, uint256 chainId, address account)
    external
    view
    returns (bool hasVoted, uint256 votingPower, uint256 gaugeSum, uint32[] memory gauges)
  {
    StorageV1 storage $ = _getStorageV1();
    Epoch storage epoch = _epoch($, epochId);
    votingPower = _getVotingPower($, epoch, account);

    (bool exists, uint256 latestVotedEpochId) = _latestVotedEpochIdBefore($, epochId, chainId, account);
    if (!exists) return (false, votingPower, 0, new uint32[](0));

    EpochVoteInfo storage latestVotedEpochVoteInfo = $.epochs[latestVotedEpochId].voteInfoByChainId[chainId];
    uint256[] memory latestVotedProtocolIds = latestVotedEpochVoteInfo.protocolIds;
    uint32[] memory latestVotedGauges = latestVotedEpochVoteInfo.gaugesByAccount[account];

    uint256[] memory protocolIds_ = epoch.voteInfoByChainId[chainId].protocolIds;
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

    return (true, votingPower, gaugeSum, gauges);
  }

  //=========== NOTE: MUTATION FUNCTIONS ===========//

  function castVote(uint256 chainId, uint32[] memory gauges) external {
    StorageV1 storage $ = _getStorageV1();

    _moveToNextEpochIfNeeded($);

    Epoch storage epoch = _ongoingEpoch($);
    EpochVoteInfo storage epochVoteInfo = _getOrInitEpochVoteInfo($, epoch, chainId);

    require(gauges.length > 0, EOLAllocationGovernor__ZeroGaugesLength());
    require(
      gauges.length == epochVoteInfo.protocolIds.length,
      EOLAllocationGovernor__InvalidGaugesLength(gauges.length, epochVoteInfo.protocolIds.length)
    );
    require(_sum(gauges) == 100, EOLAllocationGovernor__InvalidGaugesSum());

    epochVoteInfo.gaugesByAccount[_msgSender()] = gauges;

    TotalVoteInfo storage totalVoteInfo = $.totalVoteInfoByChainId[chainId];
    totalVoteInfo.voters.add(_msgSender());

    uint256[] storage votedEpochIds = totalVoteInfo.votedEpochIdsByAccount[_msgSender()];
    uint256 votedEpochIdsLen = votedEpochIds.length;
    if (votedEpochIdsLen == 0 || votedEpochIds[votedEpochIdsLen - 1] < epoch.id) {
      votedEpochIds.push(epoch.id);
    }

    emit VoteCasted(epoch.id, chainId, _msgSender(), gauges);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function setEpochPeriod(uint32 epochPeriod) external onlyOwner {
    StorageV1 storage $ = _getStorageV1();

    _moveToNextEpochIfNeeded($);
    $.epochPeriod = epochPeriod;

    emit EpochPeriodSet(epochPeriod);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _epoch(StorageV1 storage $, uint256 epochId) internal view returns (Epoch storage) {
    Epoch storage epoch = $.epochs[epochId];
    require(epoch.id != 0, EOLAllocationGovernor__EpochNotFound(epochId));
    return epoch;
  }

  function _ongoingEpoch(StorageV1 storage $) internal view returns (Epoch storage) {
    Epoch storage epoch = _epoch($, $.lastEpochId);
    uint48 currentTime = $.eolAsset.clock();

    require(
      currentTime >= epoch.startsAt && currentTime < epoch.endsAt, EOLAllocationGovernor__EpochNotOngoing(epoch.id)
    );

    return epoch;
  }

  function _latestVotedEpochIdBefore(StorageV1 storage $, uint256 epochIdBefore, uint256 chainId, address account)
    internal
    view
    returns (bool exists, uint256 latestVotedEpochId)
  {
    uint256[] memory votedEpochIds = $.totalVoteInfoByChainId[chainId].votedEpochIdsByAccount[account];
    uint256 upperBoundIdx = votedEpochIds.upperBoundMemory(epochIdBefore);
    if (upperBoundIdx == 0) return (false, 0);
    else return (true, votedEpochIds[upperBoundIdx - 1]);
  }

  function _moveToNextEpochIfNeeded(StorageV1 storage $) internal {
    uint48 currentTime = $.eolAsset.clock();
    Epoch storage epoch = _ongoingEpoch($);
    while (currentTime >= epoch.endsAt) {
      epoch = _moveToNextEpoch($, epoch.endsAt);
    }
  }

  function _moveToNextEpoch(StorageV1 storage $, uint48 startsAt) internal returns (Epoch storage) {
    uint256 epochId = ++$.lastEpochId;

    Epoch storage epoch = $.epochs[epochId];
    epoch.id = epochId;
    epoch.startsAt = startsAt;
    epoch.endsAt = startsAt + $.epochPeriod;

    emit EpochStarted(epoch.id, epoch.startsAt, epoch.endsAt);

    return epoch;
  }

  function _getOrInitEpochVoteInfo(StorageV1 storage $, Epoch storage epoch, uint256 chainId)
    internal
    returns (EpochVoteInfo storage)
  {
    EpochVoteInfo storage voteInfo = epoch.voteInfoByChainId[chainId];
    if (voteInfo.protocolIds.length == 0) {
      voteInfo.protocolIds = $.protocolRegistry.protocolIds(address($.eolAsset), chainId);
      emit ProtocolIdsFetched(epoch.id, chainId, voteInfo.protocolIds);
    }
    return voteInfo;
  }

  function _getVotingPower(StorageV1 storage $, Epoch storage epoch, address account) internal view returns (uint256) {
    return $.eolAsset.getAccountTWABByTimestampRange(account, epoch.startsAt - $.twabPeriod, epoch.startsAt);
  }

  function _getTotalVotingPower(StorageV1 storage $, Epoch storage epoch) internal view returns (uint256) {
    return $.eolAsset.getTotalTWABByTimestampRange(epoch.startsAt - $.twabPeriod, epoch.startsAt);
  }

  function _sum(uint32[] memory arr) internal pure returns (uint256 sum) {
    for (uint256 i = 0; i < arr.length; i++) {
      sum += arr[i];
    }
    return sum;
  }
}
