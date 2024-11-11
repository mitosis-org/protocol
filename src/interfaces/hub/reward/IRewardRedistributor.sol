// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IRewardRedistributor {
  event RedistributionCreated(uint256 indexed id);
  event RewardsReserved(
    uint256 indexed id,
    address indexed account,
    address indexed eolVault,
    address reward,
    uint48 toTimestamp,
    uint256 claimedAmount
  );
  event RedistributionExecuted(uint256 indexed id, uint256 indexed merkleStage, bytes32 merkleRoot);

  function redistribution(uint256 id)
    external
    view
    returns (bool exists, address[] memory rewards, uint256[] memory amounts, uint256 merkleStage, bytes32 merkleRoot);

  function reserveRewards(uint256 id, address account, address eolVault, address reward, uint48 toTimestamp) external;

  function executeRedistribution(uint256 id, bytes32 merkleRoot) external returns (uint256 merkleStage);
}
