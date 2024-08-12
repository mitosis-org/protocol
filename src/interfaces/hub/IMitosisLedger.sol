// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisLedger {
  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);
  function getEolAllocateAmount(address miAsset) external view returns (uint256);

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;

  function recordOptIn(address miAsset, uint256 amount) external;
  function recordOptOutRequest(address miAsset, uint256 amount) external;
  function recordOptOutRelease(address miAsset, uint256 amount) external;
  function recordOptOutResolve(address miAsset, uint256 amount) external;
  function recordOptOutClaim(address miAsset, uint256 amount) external;
}
