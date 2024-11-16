// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IRewardRedistributor {
  struct Redistribution {
    uint256 id;
    uint256 nonce;
    uint256 merkleStage;
    bytes32 merkleRoot;
    address[] rewards;
    uint256[] amounts;
  }

  event RedistributionCreated(uint256 indexed id);

  event RewardsFetched(
    uint256 indexed id,
    uint256 nonce,
    address indexed account,
    address indexed eolVault,
    address reward,
    uint256 amount,
    uint48 toTimestamp
  );

  event RedistributionExecuted(
    uint256 indexed id, uint256 indexed merkleStage, bytes32 merkleRoot, address[] rewards, uint256[] amounts
  );

  error IRewardRedistributor__NotCurrentRedistributionId(uint256 id);
  error IRewardRedistributor__RedistributionNotFound(uint256 id);
  error IRewardRedistributor__RedistributionInvalidNonce(uint256 id, uint256 nonce);

  // ================= VIEW FUNCTIONS ================= //

  function currentId() external view returns (uint256);

  function redistribution(uint256 id) external view returns (Redistribution memory redist);
}
