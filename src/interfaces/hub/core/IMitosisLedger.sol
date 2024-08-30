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
    /// @notice This value reflects the amount of underlying assets that
    /// are pending to be opt-out.
    /// (i.e. This means that from the point of the opt-out request, yield
    /// will not be provided for the corresponding miAsset)
    uint256 optOutPending;
    /// @dev optOutResolved is the actual amount used for the opt-out request
    /// resolvation.
    /// @notice This value reflects the amount of underlying assets that
    /// have been used for the opt-out request.
    uint256 optOutResolved;
  }

  function optOutQueue() external view returns (address);

  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);

  function eolStrategist(address eolVault) external view returns (address);
  function eolAmountState(address eolVault) external view returns (EOLAmountState memory);
  function getEOLAllocateAmount(address eolVault) external view returns (uint256);
  // EOL management
  function setEolStrategist(address eolVault, address strategist) external;
  // Asset Record
  function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;
  // EOL Record
  function recordOptIn(address eolVault, uint256 amount) external;
  function recordOptOutRequest(address eolVault, uint256 amount) external;
  function recordAllocateEOL(address eolVault, uint256 amount) external;
  function recordDeallocateEOL(address eolVault, uint256 amount) external;
  function recordOptOutResolve(address eolVault, uint256 amount) external;
  function recordOptOutClaim(address eolVault, uint256 amount) external;
}
