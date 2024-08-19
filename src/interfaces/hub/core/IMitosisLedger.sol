// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisLedger {
  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);
  function getEOLAllocateAmount(uint256 eolId) external view returns (uint256);
  function eolAmountState(uint256 eolId)
    external
    view
    returns (uint256 total, uint256 idle, uint256 optOutPending, uint256 optOutResolved);

  function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;

  function recordOptIn(uint256 eolId, uint256 amount) external;
  function recordOptOutRequest(uint256 eolId, uint256 amount) external;
  function recordAllocateEOL(uint256 eolId, uint256 amount) external;
  function recordDeallocateEOL(uint256 eolId, uint256 amount) external;
  function recordOptOutResolve(uint256 eolId, uint256 amount) external;
  function recordOptOutClaim(uint256 eolId, uint256 amount) external;
}
