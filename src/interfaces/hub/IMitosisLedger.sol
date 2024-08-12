// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisLedger {
    // Chain state
    function getAssetAmount(uint256 chainId, address asset) external view returns (uint256);
    function getAssetAmountByAllChains(address asset) external view returns (uint256);
    // EOL state
    function getEolAllocateAmount(address miAsset) external view returns (uint256);

    function recordDeposit(uint256 chainId, address asset, uint256 amount) external;
    function recordWithdraw(uint256 chainId, address asset, uint256 amount) external;
    function recordOptIn(address miAsset, uint256 amount) external;
    function recordOptOut(address miAsset, uint256 amount) external;
    function recordOutputRequest(address miAsset, uint256 amount) external;
    function recordOutputResolve(address miAsset, uint256 amount) external;

    // TODO: EOL State get/set methods (finalized, resolved, released, pending)
}
