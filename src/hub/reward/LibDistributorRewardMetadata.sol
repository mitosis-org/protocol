// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

struct RewardTWABMetadata {
  uint48 batchTimestamp;
}

struct RewardMerkleMetadata {
  uint256 stage;
  uint256 amount;
  bytes32[] proof;
}

library LibDistributorRewardMetadata {
  using SafeCast for uint256;

  error LibDistributorRewardMetadata__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(RewardTWABMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.batchTimestamp);
  }

  function decodeRewardTWABMetadata(bytes calldata enc) internal pure returns (RewardTWABMetadata memory metadata) {
    if (enc.length != 6) revert LibDistributorRewardMetadata__InvalidMsgLength(enc.length, 6);

    metadata.batchTimestamp = uint48(bytes6(enc[0:6]));
  }

  function encode(RewardMerkleMetadata memory metadata) internal pure returns (bytes memory ret) {
    ret = abi.encodePacked(metadata.stage, metadata.amount, metadata.proof.length.toUint8(), metadata.proof);

    return ret;
  }

  function decodeRewardMerkleMetadata(bytes calldata enc) internal pure returns (RewardMerkleMetadata memory item) {
    item.stage = uint256(bytes32(enc[0:32]));
    item.amount = uint256(bytes32(enc[32:64]));
    item.proof = new bytes32[](uint8(enc[64]));

    uint256 expectedLength = 65 + item.proof.length * 32;
    require(enc.length == expectedLength, LibDistributorRewardMetadata__InvalidMsgLength(enc.length, expectedLength));

    for (uint256 i = 0; i < item.proof.length; i++) {
      item.proof[i] = bytes32(enc[65 + i * 32:65 + (i + 1) * 32]);
    }

    return item;
  }
}
