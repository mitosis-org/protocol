// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IEOLProtocolRegistry } from '../../interfaces/eol/IEOLProtocolRegistry.sol';
import { IEOLAllocationGovernorStorageV1 } from '../../interfaces/hub/governance/IEOLAllocationGovernor.sol';
import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';

struct Epoch {
  uint256 id;
  uint48 startsAt;
  uint48 endsAt;
  mapping(uint256 chainId => EpochVoteInfo) voteInfoByChainId;
}

struct EpochVoteInfo {
  uint256[] protocolIds;
  mapping(address account => uint32[] gauges) gaugesByAccount;
}

struct TotalVoteInfo {
  EnumerableSet.AddressSet voters;
  mapping(address account => uint256[] votedEpochIds) votedEpochIdsByAccount;
}

contract EOLAllocationGovernorStorageV1 is IEOLAllocationGovernorStorageV1 {
  using TWABSnapshotsUtils for ITWABSnapshots;
  using EnumerableSet for EnumerableSet.AddressSet;
  using ERC7201Utils for string;

  event EpochStarted(uint256 indexed epochId, uint48 startsAt, uint48 endsAt);
  event EpochPeriodSet(uint32 epochPeriod);

  error EOLAllocationGovernorStorageV1__EpochNotFound(uint256 epochId);
  error EOLAllocationGovernorStorageV1__EpochNotOngoing(uint256 epochId);

  struct StorageV1 {
    IEOLProtocolRegistry protocolRegistry;
    ITWABSnapshots eolAsset;
    uint32 twabPeriod;
    uint32 epochPeriod;
    uint256 lastEpochId;
    mapping(uint256 epochId => Epoch) epochs;
    mapping(uint256 chainId => TotalVoteInfo) totalVoteInfoByChainId;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLAllocationGovernorStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
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

  //
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

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function _setEpochPeriod(uint32 epochPeriod) internal {
    StorageV1 storage $ = _getStorageV1();

    _moveToNextEpochIfNeeded($);
    $.epochPeriod = epochPeriod;

    emit EpochPeriodSet(epochPeriod);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _epoch(StorageV1 storage $, uint256 epochId) internal view returns (Epoch storage) {
    Epoch storage epoch = $.epochs[epochId];
    require(epoch.id != 0, EOLAllocationGovernorStorageV1__EpochNotFound(epochId));
    return epoch;
  }

  function _ongoingEpoch(StorageV1 storage $) internal view returns (Epoch storage) {
    Epoch storage epoch = _epoch($, $.lastEpochId);
    uint48 currentTime = $.eolAsset.clock();

    require(
      currentTime >= epoch.startsAt && currentTime < epoch.endsAt,
      EOLAllocationGovernorStorageV1__EpochNotOngoing(epoch.id)
    );

    return epoch;
  }

  function _getTotalVotingPower(StorageV1 storage $, Epoch storage epoch) internal view returns (uint256) {
    return $.eolAsset.getTotalTWABByTimestampRange(epoch.startsAt - $.twabPeriod, epoch.startsAt);
  }
}
