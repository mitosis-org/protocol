// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct RewardTWABMetadata {
  address erc20TWABSnapshots;
  uint48 rewardedAt;
}

library LibDistributorRewardMetadata {
  error LibDistributorRewardMetadata__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(RewardTWABMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.erc20TWABSnapshots, metadata.rewardedAt);
  }

  function decodeRewardTWABMetadata(bytes calldata enc) internal pure returns (RewardTWABMetadata memory metadata) {
    if (enc.length != 26) revert LibDistributorRewardMetadata__InvalidMsgLength(enc.length, 26);

    metadata.erc20TWABSnapshots = address(bytes20(enc[0:20]));
    metadata.rewardedAt = uint48(bytes6(enc[20:26]));
  }
}
