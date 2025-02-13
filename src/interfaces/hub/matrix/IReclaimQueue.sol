// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IHubAsset } from '../core/IHubAsset.sol';
import { IMatrixVault } from './IMatrixVault.sol';

/**
 * @title IReclaimQueueStorageV1
 * @notice Storage interface for ReclaimQueue, defining getter functions and events for storage operations
 * @dev Provides the foundation for managing reclaim requests in MatrixVaults
 */
interface IReclaimQueueStorageV1 {
  /**
   * @notice Reclaim request status enumeration
   */
  enum RequestStatus {
    None,
    Requested,
    Claimable,
    Claimed
  }

  /**
   * @notice Detailed information about a specific reclaim request
   * @param id Unique identifier of the request
   * @param shares Number of shares requested in the reclaim
   * @param recipient Address that will receive the assets
   * @param createdAt Timestamp when the request was created
   * @param claimedAt Timestamp when the request was claimed (0 if unclaimed)
   */
  struct GetRequestResponse {
    uint256 id;
    uint256 shares;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
  }

  /**
   * @notice Detailed information about a request, including its index in the queue
   * @param id Unique identifier of the request
   * @param indexId Position of the request in the recipient's index
   * @param shares Number of shares requested in the reclaim
   * @param recipient Address that will receive the assets
   * @param createdAt Timestamp when the request was created
   * @param claimedAt Timestamp when the request was claimed (0 if unclaimed)
   */
  struct GetRequestByIndexResponse {
    uint256 id;
    uint256 indexId;
    uint256 shares;
    address recipient;
    uint48 createdAt;
    uint48 claimedAt;
  }

  /**
   * @notice Historical data about reserves at a specific point in time
   * @param reserved Reserved amount for specific log
   * @param reservedAt Timestamp when this reserve entry was created
   * @param totalShares Total shares in the MatrixVault at this point
   * @param totalAssets Total assets in the MatrixVault at this point
   */
  struct GetReserveHistoryResponse {
    uint256 reserved;
    uint48 reservedAt;
    uint256 totalShares;
    uint256 totalAssets;
  }

  /**
   * @notice Emitted when an reclaim queue is activated for an MatrixVault
   * @param matrixVault Address of the MatrixVault for which the queue is enabled
   */
  event QueueEnabled(address indexed matrixVault);

  /**
   * @notice Emitted when a new asset manager is set for the contract
   * @param assetManager Address of the newly set asset manager
   */
  event AssetManagerSet(address indexed assetManager);

  /**
   * @notice Emitted when the redeem period is updated for an MatrixVault
   * @param matrixVault Address of the MatrixVault for which the redeem period is set
   * @param redeemPeriod Duration of the new redeem period in seconds
   */
  event RedeemPeriodSet(address indexed matrixVault, uint256 redeemPeriod);

  /**
   * @notice Retrieves the current asset manager address
   */
  function assetManager() external view returns (address);

  /**
   * @notice Gets the redeem period duration in seconds for a specific MatrixVault
   * @param matrixVault Address of the MatrixVault to query
   */
  function redeemPeriod(address matrixVault) external view returns (uint256);

  /**
   * @notice Retrieves the status of a specific reclaim request
   * @param matrixVault Address of the MatrixVault to query
   * @param reqId ID of the request to query
   */
  function getStatus(address matrixVault, uint256 reqId) external view returns (RequestStatus);

  /**
   * @notice Retrieves details for multiple requests from a specific MatrixVault
   * @param matrixVault Address of the MatrixVault to query
   * @param reqIds Array of request IDs to retrieve
   */
  function getRequest(address matrixVault, uint256[] calldata reqIds)
    external
    view
    returns (GetRequestResponse[] memory);

  /**
   * @notice Gets details for multiple requests for a specific receiver from an MatrixVault
   * @dev Use queueIndexOffset to get the starting index for retrieval
   * @param matrixVault Address of the MatrixVault to query
   * @param receiver Address of the receiver to query
   * @param idxItemIds Array of index item IDs to retrieve
   */
  function getRequestByReceiver(address matrixVault, address receiver, uint256[] calldata idxItemIds)
    external
    view
    returns (GetRequestByIndexResponse[] memory);

  /**
   * @notice Retrieves the timestamp when a specific request was reserved
   * @param matrixVault Address of the MatrixVault to query
   * @param reqId ID of the request to query
   * @return reservedAt_ Timestamp when the request was reserved
   * @return isReserved Boolean indicating if the request is reserved
   */
  function reservedAt(address matrixVault, uint256 reqId) external view returns (uint256 reservedAt_, bool isReserved);

  /**
   * @notice Gets the timestamp when a specific request was resolved
   * @param matrixVault Address of the MatrixVault to query
   * @param reqId ID of the request to query
   * @return resolvedAt_ Timestamp when the request was resolved
   * @return isResolved Boolean indicating if the request is resolved
   */
  function resolvedAt(address matrixVault, uint256 reqId) external view returns (uint256 resolvedAt_, bool isResolved);

  /**
   * @notice Retrieves the total amount of reserved assets for an MatrixVault's queue
   * @param matrixVault Address of the MatrixVault to query
   */
  function totalReserved(address matrixVault) external view returns (uint256);

  /**
   * @notice Retrieves the total amount of pending assets for an MatrixVault's queue
   * @param matrixVault Address of the MatrixVault to query
   */
  function totalPending(address matrixVault) external view returns (uint256);

  /**
   * @notice Gets the reserve history entry for a specific index in an MatrixVault
   * @param matrixVault Address of the MatrixVault to query
   * @param index Index of the reserve history entry to retrieve
   * @return resp GetReserveHistoryResponse struct containing the reserve history data
   */
  function reserveHistory(address matrixVault, uint256 index)
    external
    view
    returns (GetReserveHistoryResponse memory resp);

  /**
   * @notice Retrieves the number of entries in the reserve history for an MatrixVault
   * @param matrixVault Address of the MatrixVault to query
   */
  function reserveHistoryLength(address matrixVault) external view returns (uint256);

  /**
   * @notice Checks if the reclaim queue is enabled for a specific MatrixVault
   * @param matrixVault Address of the MatrixVault to query
   */
  function isEnabled(address matrixVault) external view returns (bool);
}

/**
 * @title IReclaimQueue
 * @notice Interface for managing reclaim requests in MatrixVaults
 * @dev Extends IReclaimQueueStorageV1 with queue management and configuration functions
 */
interface IReclaimQueue is IReclaimQueueStorageV1 {
  /**
   * @notice Configuration parameters for processing claim requests
   * @dev Used internally to pass data during claim processing
   * @param timestamp Current timestamp for the claim
   * @param receiver Address receiving the claim
   * @param matrixVault MatrixVault contract interface
   * @param hubAsset Hub asset contract interface
   * @param decimalsOffset Difference in decimals between MatrixVault and hub asset
   * @param queueOffset Current offset in the main queue
   * @param idxOffset Current offset in the receiver's index
   */
  struct ClaimConfig {
    uint256 timestamp;
    address receiver;
    IMatrixVault matrixVault;
    IHubAsset hubAsset;
    uint8 decimalsOffset;
    uint256 queueOffset;
    uint256 idxOffset;
  }

  /**
   * @notice Emitted when a new reclaim request is added to the queue
   * @param receiver Address that will receive the assets
   * @param matrixVault Address of the MatrixVault
   * @param shares Number of shares being opted out
   * @param assets Equivalent asset amount at time of request
   */
  event ReclaimRequested(address indexed receiver, address indexed matrixVault, uint256 shares, uint256 assets);

  /**
   * @notice Emitted when an reclaim request is successfully claimed
   * @param receiver Address receiving the claim
   * @param matrixVault Address of the MatrixVault
   * @param claimed Amount of assets claimed
   */
  event ReclaimRequestClaimed(address indexed receiver, address indexed matrixVault, uint256 claimed);

  /**
   * @notice Error thrown when trying to interact with a disabled queue
   * @param matrixVault Address of the MatrixVault with the disabled queue
   */
  error IReclaimQueue__QueueNotEnabled(address matrixVault);

  /**
   * @notice Error thrown when attempting to claim with no eligible requests
   */
  error IReclaimQueue__NothingToClaim();

  /**
   * @notice Submits a new reclaim request
   * @param shares Number of shares to opt out
   * @param receiver Address that will receive the assets
   * @param matrixVault Address of the MatrixVault to opt out from
   * @return reqId Unique identifier for the queued request
   */
  function request(uint256 shares, address receiver, address matrixVault) external returns (uint256 reqId);

  /**
   * @notice Processes and fulfills eligible reclaim requests for a receiver
   * @param receiver Address of the receiver claiming their requests
   * @param matrixVault Address of the MatrixVault to claim from
   * @return totalClaimed_ Total amount of assets claimed
   */
  function claim(address receiver, address matrixVault) external returns (uint256 totalClaimed_);

  /**
   * @notice Updates the queue with available idle balance
   * @dev Can only be called by the asset manager
   * @param executor Address of the executor calling the function
   * @param matrixVault Address of the MatrixVault to update
   * @param assets Amount of idle assets to allocate to pending requests
   */
  function sync(address executor, address matrixVault, uint256 assets) external;

  /**
   * @notice Activates the reclaim queue for an MatrixVault
   * @dev Can only be called by the contract owner
   * @param matrixVault Address of the MatrixVault to enable the queue for
   */
  function enable(address matrixVault) external;

  /**
   * @notice Sets the duration of the redeem period for an MatrixVault
   * @dev Can only be called by the contract owner
   * @param matrixVault Address of the MatrixVault to set the redeem period for
   * @param redeemPeriod_ Duration of the redeem period in seconds
   */
  function setRedeemPeriod(address matrixVault, uint256 redeemPeriod_) external;
}
