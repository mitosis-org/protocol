// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisLedger {
  function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);

  function eolVault(uint256 eolId) external view returns (address);
  function eolStrategist(uint256 eolId) external view returns (address);
  function eolAmountState(uint256 eolId)
    external
    view
    returns (uint256 total, uint256 idle, uint256 optOutPending, uint256 optOutResolved);
  function getEOLAllocateAmount(uint256 eolId) external view returns (uint256);
  // EOL management
  function allocateEolId(address eolVault_) external returns (uint256 eolId);
  function allocateEolId(address eolVault_, address strategist) external returns (uint256 eolId);
  function setEolStrategist(uint256 eolId, address strategist) external;
  // Asset Record
  function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
  function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;
  // EOL Record
  function recordOptIn(uint256 eolId, uint256 amount) external;
  function recordOptOutRequest(uint256 eolId, uint256 amount) external;
  function recordAllocateEOL(uint256 eolId, uint256 amount) external;
  function recordDeallocateEOL(uint256 eolId, uint256 amount) external;
  function recordOptOutResolve(uint256 eolId, uint256 amount) external;
  function recordOptOutClaim(uint256 eolId, uint256 amount) external;
}
