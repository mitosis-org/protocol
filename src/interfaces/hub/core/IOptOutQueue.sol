// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { LibRedeemQueue } from '../../../lib/LibRedeemQueue.sol';
import { IEOLVault } from '../eol/IEOLVault.sol';
import { IHubAsset } from './IHubAsset.sol';

interface IOptOutQueueStorageV1 {
  struct GetRequestResponse {
    uint256 id;
    LibRedeemQueue.Request request;
  }

  struct GetRequestByIndexResponse {
    uint256 id;
    uint256 indexId;
    LibRedeemQueue.Request request;
  }

  event QueueEnabled(address indexed eolVault);
  event AssetManagerSet(address indexed assetManager);
  event RedeemPeriodSet(address indexed eolVault, uint256 redeemPeriod);

  // View functions

  function assetManager() external view returns (address);

  function redeemPeriod(address eolVault) external view returns (uint256);

  function getRequest(address eolVault, uint256[] calldata reqIds)
    external
    view
    returns (GetRequestResponse[] memory resp);
  function getRequestByReceiver(address eolVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (GetRequestByIndexResponse[] memory resp);

  function reservedAt(address eolVault, uint256 reqId) external view returns (uint256 reservedAt_, bool isReserved);
  function resolvedAt(address eolVault, uint256 reqId) external view returns (uint256 resolvedAt_, bool isResolved);
  function requestShares(address eolVault, uint256 reqId) external view returns (uint256);
  function requestAssets(address eolVault, uint256 reqId) external view returns (uint256);

  function queueSize(address eolVault) external view returns (uint256);
  function queueIndexSize(address eolVault, address recipient) external view returns (uint256);
  function queueOffset(address eolVault, bool simulate) external view returns (uint256 offset);
  function queueIndexOffset(address eolVault, address recipient, bool simulate) external view returns (uint256 offset);

  function totalReserved(address eolVault) external view returns (uint256);
  function totalClaimed(address eolVault) external view returns (uint256);
  function totalPending(address eolVault) external view returns (uint256);

  function reserveHistory(address eolVault, uint256 index) external view returns (LibRedeemQueue.ReserveLog memory);
  function reserveHistoryLength(address eolVault) external view returns (uint256);

  function isEnabled(address eolVault) external view returns (bool);
}

interface IOptOutQueue is IOptOutQueueStorageV1 {
  struct ClaimConfig {
    uint256 timestamp;
    address receiver;
    IEOLVault eolVault;
    IHubAsset hubAsset;
    uint8 decimalsOffset;
    uint256 queueOffset;
    uint256 idxOffset;
  }

  enum ImpactType {
    None,
    Loss,
    Yield
  }

  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 shares, uint256 assets);
  event OptOutYieldReported(address indexed receiver, address indexed eolVault, uint256 yield);
  event OptOutRequestClaimed(
    address indexed receiver, address indexed eolVault, uint256 claimed, uint256 impact, ImpactType impactType
  );

  error IOptOutQueue__QueueNotEnabled(address eolVault);
  error IOptOutQueue__NothingToClaim();

  // Queue functions
  function request(uint256 shares, address receiver, address eolVault) external returns (uint256 reqId);
  function claim(address receiver, address eolVault) external returns (uint256 totalClaimed_);
  function sync(address eolVault, uint256 assets) external;

  // Config functions
  function enable(address eolVault) external;
  function setRedeemPeriod(address eolVault, uint256 redeemPeriod_) external;
}
