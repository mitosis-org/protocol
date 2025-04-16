// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IHubAsset } from '../core/IHubAsset.sol';
import { IEOLVault } from '../eol/vault/IEOLVault.sol';

/**
 * @title IOptOutQueueStorageV1
 * @notice Storage interface for OptOutQueue, defining getter functions and events for storage operations
 * @dev Provides the foundation for managing opt-out requests in EOLVaults
 */
interface IOptOutQueueStorageV1 {
  /**
   * @notice Opt-out request status enumeration
   */
  enum RequestStatus {
    None,
    Requested,
    Claimable,
    Claimed
  }

  /**
   * @notice Detailed information about a specific opt-out request
   * @param id Unique identifier of the request
   * @param requestedShares Number of shares requested in the opt-out
   * @param requestedAssets Equivalent asset amount at time of request
   * @param accumulatedShares Total shares accumulated up to this request
   * @param accumulatedAssets Total assets accumulated up to this request
   * @param recipient Address that will receive the assets
   * @param createdAt Timestamp when the request was created
   * @param claimedAt Timestamp when the request was claimed (0 if unclaimed)
   */
  struct GetRequestResponse {
    uint256 id;
    uint256 requestedShares;
    uint256 requestedAssets;
    uint256 accumulatedShares;
    uint256 accumulatedAssets;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
  }

  /**
   * @notice Detailed information about a request, including its index in the queue
   * @param id Unique identifier of the request
   * @param indexId Position of the request in the recipient's index
   * @param requestedShares Number of shares requested in the opt-out
   * @param requestedAssets Equivalent asset amount at time of request
   * @param accumulatedShares Total shares accumulated up to this request
   * @param accumulatedAssets Total assets accumulated up to this request
   * @param recipient Address that will receive the assets
   * @param createdAt Timestamp when the request was created
   * @param claimedAt Timestamp when the request was claimed (0 if unclaimed)
   */
  struct GetRequestByIndexResponse {
    uint256 id;
    uint256 indexId;
    uint256 requestedShares;
    uint256 requestedAssets;
    uint256 accumulatedShares;
    uint256 accumulatedAssets;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
  }

  /**
   * @notice Historical data about reserves at a specific point in time
   * @param accumulated Total accumulated reserve assets at this point
   * @param reservedAt Timestamp when this reserve entry was created
   * @param totalShares Total shares in the EOLVault at this point
   * @param totalAssets Total assets in the EOLVault at this point
   */
  struct GetReserveHistoryResponse {
    uint256 accumulated;
    uint48 reservedAt;
    uint208 totalShares;
    uint208 totalAssets;
  }

  /**
   * @notice Emitted when an opt-out queue is activated for an EOLVault
   * @param eolVault Address of the EOLVault for which the queue is enabled
   */
  event QueueEnabled(address indexed eolVault);

  /**
   * @notice Emitted when a new asset manager is set for the contract
   * @param assetManager Address of the newly set asset manager
   */
  event AssetManagerSet(address indexed assetManager);

  /**
   * @notice Emitted when the redeem period is updated for an EOLVault
   * @param eolVault Address of the EOLVault for which the redeem period is set
   * @param redeemPeriod Duration of the new redeem period in seconds
   */
  event RedeemPeriodSet(address indexed eolVault, uint256 redeemPeriod);

  /**
   * @notice Retrieves the current asset manager address
   */
  function assetManager() external view returns (address);

  /**
   * @notice Gets the redeem period duration in seconds for a specific EOLVault
   * @param eolVault Address of the EOLVault to query
   */
  function redeemPeriod(address eolVault) external view returns (uint256);

  /**
   * @notice Retrieves the status of a specific opt-out request
   * @param eolVault Address of the EOLVault to query
   * @param reqId ID of the request to query
   */
  function getStatus(address eolVault, uint256 reqId) external view returns (RequestStatus);

  /**
   * @notice Retrieves details for multiple requests from a specific EOLVault
   * @param eolVault Address of the EOLVault to query
   * @param reqIds Array of request IDs to retrieve
   */
  function getRequest(address eolVault, uint256[] calldata reqIds) external view returns (GetRequestResponse[] memory);

  /**
   * @notice Gets details for multiple requests for a specific receiver from an EOLVault
   * @dev Use queueIndexOffset to get the starting index for retrieval
   * @param eolVault Address of the EOLVault to query
   * @param receiver Address of the receiver to query
   * @param idxItemIds Array of index item IDs to retrieve
   */
  function getRequestByReceiver(address eolVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (GetRequestByIndexResponse[] memory);

  /**
   * @notice Retrieves the timestamp when a specific request was reserved
   * @param eolVault Address of the EOLVault to query
   * @param reqId ID of the request to query
   * @return reservedAt_ Timestamp when the request was reserved
   * @return isReserved Boolean indicating if the request is reserved
   */
  function reservedAt(address eolVault, uint256 reqId) external view returns (uint256 reservedAt_, bool isReserved);

  /**
   * @notice Gets the timestamp when a specific request was resolved
   * @param eolVault Address of the EOLVault to query
   * @param reqId ID of the request to query
   * @return resolvedAt_ Timestamp when the request was resolved
   * @return isResolved Boolean indicating if the request is resolved
   */
  function resolvedAt(address eolVault, uint256 reqId) external view returns (uint256 resolvedAt_, bool isResolved);

  /**
   * @notice Retrieves the number of shares for a specific request
   * @param eolVault Address of the EOLVault to query
   * @param reqId ID of the request to query
   */
  function requestShares(address eolVault, uint256 reqId) external view returns (uint256);

  /**
   * @notice Gets the amount of assets for a specific request
   * @param eolVault Address of the EOLVault to query
   * @param reqId ID of the request to query
   */
  function requestAssets(address eolVault, uint256 reqId) external view returns (uint256);

  /**
   * @notice Retrieves the current size of the queue for a specific EOLVault
   * @dev The queue size is the total number of requests in the queue
   * @param eolVault Address of the EOLVault to query the queue
   */
  function queueSize(address eolVault) external view returns (uint256);

  /**
   * @notice Gets the size of the queue index for a specific recipient in an EOLVault
   * @param eolVault Address of the EOLVault to query the queue
   * @param recipient Address of the recipient to query the index for
   */
  function queueIndexSize(address eolVault, address recipient) external view returns (uint256);

  /**
   * @notice Retrieves the current or simulated offset of the queue for an EOLVault
   * @param eolVault Address of the EOLVault to query
   * @param simulate If true, returns the simulated offset based on current timestamp
   */
  function queueOffset(address eolVault, bool simulate) external view returns (uint256);

  /**
   * @notice Gets the current or simulated offset of the queue index for a recipient in an EOLVault
   * @param eolVault Address of the EOLVault to query
   * @param recipient Address of the recipient to query
   * @param simulate If true, returns the simulated offset based on current timestamp
   */
  function queueIndexOffset(address eolVault, address recipient, bool simulate) external view returns (uint256);

  /**
   * @notice Retrieves the total amount of reserved assets for an EOLVault's queue
   * @param eolVault Address of the EOLVault to query
   */
  function totalReserved(address eolVault) external view returns (uint256);

  /**
   * @notice Gets the total amount of claimed assets for an EOLVault's queue
   * @param eolVault Address of the EOLVault to query
   */
  function totalClaimed(address eolVault) external view returns (uint256);

  /**
   * @notice Retrieves the total amount of pending assets for an EOLVault's queue
   * @param eolVault Address of the EOLVault to query
   */
  function totalPending(address eolVault) external view returns (uint256);

  /**
   * @notice Gets the reserve history entry for a specific index in an EOLVault
   * @param eolVault Address of the EOLVault to query
   * @param index Index of the reserve history entry to retrieve
   * @return resp GetReserveHistoryResponse struct containing the reserve history data
   */
  function reserveHistory(address eolVault, uint256 index)
    external
    view
    returns (GetReserveHistoryResponse memory resp);

  /**
   * @notice Retrieves the number of entries in the reserve history for an EOLVault
   * @param eolVault Address of the EOLVault to query
   */
  function reserveHistoryLength(address eolVault) external view returns (uint256);

  /**
   * @notice Checks if the opt-out queue is enabled for a specific EOLVault
   * @param eolVault Address of the EOLVault to query
   */
  function isEnabled(address eolVault) external view returns (bool);
}

/**
 * @title IOptOutQueue
 * @notice Interface for managing opt-out requests in EOLVaults
 * @dev Extends IOptOutQueueStorageV1 with queue management and configuration functions
 */
interface IOptOutQueue is IOptOutQueueStorageV1 {
  /**
   * @notice Configuration parameters for processing claim requests
   * @dev Used internally to pass data during claim processing
   * @param timestamp Current timestamp for the claim
   * @param receiver Address receiving the claim
   * @param eolVault EOLVault contract interface
   * @param hubAsset Hub asset contract interface
   * @param decimalsOffset Difference in decimals between EOLVault and hub asset
   * @param queueOffset Current offset in the main queue
   * @param idxOffset Current offset in the receiver's index
   */
  struct ClaimConfig {
    uint256 timestamp;
    address receiver;
    IEOLVault eolVault;
    IHubAsset hubAsset;
    uint8 decimalsOffset;
    uint256 queueOffset;
    uint256 idxOffset;
  }

  /**
   * @notice Types of value effect on an opt-out request before and after claiming
   */
  enum ImpactType {
    None,
    /// loss settled during the opt-out process.
    /// receiver will get the assets with the loss.
    /// other assets will be sent to the vault.
    Loss,
    /// yield generated during the opt-out process
    /// but we decided to send it to the vault. not to the receiver.
    /// receiver will get the assets that determined at the time of request.
    Yield
  }

  /**
   * @notice Emitted when a new opt-out request is added to the queue
   * @param receiver Address that will receive the assets
   * @param eolVault Address of the EOLVault
   * @param shares Number of shares being opted out
   * @param assets Equivalent asset amount at time of request
   */
  event OptOutRequested(address indexed receiver, address indexed eolVault, uint256 shares, uint256 assets);

  /**
   * @notice Emitted when a yield is generated during the opt-out process
   * @param receiver Address receiving the claim
   * @param eolVault Address of the EOLVault
   * @param yield Amount of yield generated
   */
  event OptOutYieldReported(address indexed receiver, address indexed eolVault, uint256 yield);

  /**
   * @notice Emitted when an opt-out request is successfully claimed
   * @param receiver Address receiving the claim
   * @param eolVault Address of the EOLVault
   * @param claimed Amount of assets claimed
   * @param impact Difference between requested and claimed amounts
   * @param impactType Type of financial impact (None, Loss, or Yield)
   */
  event OptOutRequestClaimed(
    address indexed receiver, address indexed eolVault, uint256 claimed, uint256 impact, ImpactType impactType
  );

  /**
   * @notice Error thrown when trying to interact with a disabled queue
   * @param eolVault Address of the EOLVault with the disabled queue
   */
  error IOptOutQueue__QueueNotEnabled(address eolVault);

  /**
   * @notice Error thrown when attempting to claim with no eligible requests
   */
  error IOptOutQueue__NothingToClaim();

  /**
   * @notice Submits a new opt-out request
   * @param shares Number of shares to opt out
   * @param receiver Address that will receive the assets
   * @param eolVault Address of the EOLVault to opt out from
   * @return reqId Unique identifier for the queued request
   */
  function request(uint256 shares, address receiver, address eolVault) external returns (uint256 reqId);

  /**
   * @notice Processes and fulfills eligible opt-out requests for a receiver
   * @param receiver Address of the receiver claiming their requests
   * @param eolVault Address of the EOLVault to claim from
   * @return totalClaimed_ Total amount of assets claimed
   */
  function claim(address receiver, address eolVault) external returns (uint256 totalClaimed_);

  /**
   * @notice Updates the queue with available idle balance
   * @dev Can only be called by the asset manager
   * @param eolVault Address of the EOLVault to update
   * @param assets Amount of idle assets to allocate to pending requests
   */
  function sync(address eolVault, uint256 assets) external;

  /**
   * @notice Activates the opt-out queue for an EOLVault
   * @dev Can only be called by the contract owner
   * @param eolVault Address of the EOLVault to enable the queue for
   */
  function enable(address eolVault) external;

  /**
   * @notice Sets the duration of the redeem period for an EOLVault
   * @dev Can only be called by the contract owner
   * @param eolVault Address of the EOLVault to set the redeem period for
   * @param redeemPeriod_ Duration of the redeem period in seconds
   */
  function setRedeemPeriod(address eolVault, uint256 redeemPeriod_) external;
}
