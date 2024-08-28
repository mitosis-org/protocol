// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisLedger {
  struct EOLAmountState {
    /// @dev total is the total amount of assets that have been finalized
    /// opt-in to Mitosis L1.
    /// Note: This value must match the totalSupply of the miAsset.
    uint256 total;
    /// @dev idle stores the amount of EOL temporarily returned for a
    /// specific purpose in the branch.
    /// Note: This value does not affect the calculation of the EOL
    /// allocation for a specific chain.
    uint256 idle;
    /// @dev optOutPending is a temporary value reflecting the opt-out
    /// request. This value is used to calculate the EOL allocation for
    /// each chain.
    /// (i.e. This means that from the point of the opt-out request, yield
    /// will not be provided for the corresponding miAsset)
    uint256 optOutPending;
    /// @dev optOutResolved is the actual amount used for the opt-out request
    /// resolvation.
    uint256 optOutResolved;
  }

  function lastEolId() external view returns (uint256);

  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);

  function eolStrategist(address eolVault_) external view returns (address);
  function eolAmountState(address eolVault_) external view returns (EOLAmountState memory);
  function getEOLAllocateAmount(address eolVault_) external view returns (uint256);
  function eolVaultById(uint256 eolId) external view returns (address);

  // EOL management
  function assignEolId(address eolVault_) external returns (uint256 eolId);
  function assignEolId(address eolVault_, address strategist) external returns (uint256 eolId);
  function setEolStrategist(address eolVault_, address strategist) external;
  function setOptOutQueue(address optOutQueue_) external;
  // Asset Record
  function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;
  // EOL Record
  function recordOptIn(address eolVault_, uint256 amount) external;
  function recordOptOutRequest(address eolVault_, uint256 amount) external;
  function recordAllocateEOL(address eolVault_, uint256 amount) external;
  function recordDeallocateEOL(address eolVault_, uint256 amount) external;
  function recordOptOutResolve(address eolVault_, uint256 amount) external;
  function recordOptOutClaim(address eolVault_, uint256 amount) external;
}
