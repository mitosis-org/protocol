// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

struct RewardTWABMetadata {
  address twabCriteria;
  uint48 rewardedAt;
}

struct RewardMerkleMetadata {
  address eolVault;
  uint256 stage;
  uint256 amount;
  bytes32[] proof;
}

library LibDistributorRewardMetadata {
  using SafeCast for uint256;

  error LibDistributorRewardMetadata__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(RewardTWABMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.twabCriteria, metadata.rewardedAt);
  }

  function decodeRewardTWABMetadata(bytes calldata enc) internal pure returns (RewardTWABMetadata memory metadata) {
    if (enc.length != 26) revert LibDistributorRewardMetadata__InvalidMsgLength(enc.length, 26);

    metadata.twabCriteria = address(bytes20(enc[0:20]));
    metadata.rewardedAt = uint48(bytes6(enc[20:26]));
  }

  function encode(RewardMerkleMetadata memory metadata) internal pure returns (bytes memory ret) {
    ret = abi.encodePacked(
      metadata.eolVault, metadata.stage, metadata.amount, metadata.proof.length.toUint8(), metadata.proof
    );

    return ret;
  }

  function decodeRewardMerkleMetadata(bytes calldata enc) internal pure returns (RewardMerkleMetadata memory item) {
    item.eolVault = address(bytes20(enc[0:20]));
    item.stage = uint256(bytes32(enc[20:52]));
    item.amount = uint256(bytes32(enc[52:84]));
    item.proof = new bytes32[](uint8(enc[84]));

    uint256 expectedLength = 85 + item.proof.length * 32;
    require(enc.length == expectedLength, LibDistributorRewardMetadata__InvalidMsgLength(enc.length, expectedLength));

    for (uint256 i = 0; i < item.proof.length; i++) {
      item.proof[i] = bytes32(enc[85 + i * 32:85 + (i + 1) * 32]);
    }

    return item;
  }
}
