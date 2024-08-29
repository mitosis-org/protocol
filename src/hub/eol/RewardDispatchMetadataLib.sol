// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct TWABDispatchMetadata {
  address erc20TwabSnapshots;
  uint48 timestamp;
}

library RewardDispatchMetadataLib {
  error RewardDispatchMetadataLib__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(TWABDispatchMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.erc20TwabSnapshots, metadata.timestamp);
  }

  function decodeTWABDispatchMetadata(bytes memory enc) internal pure returns (TWABDispatchMetadata memory metadata) {
    if (enc.length != 28) revert RewardDispatchMetadataLib__InvalidMsgLength(enc.length, 28);

    (address erc20TwabSnapshots, uint48 timestamp) = abi.decode(enc, (address, uint48));

    metadata.erc20TwabSnapshots = erc20TwabSnapshots;
    metadata.timestamp = timestamp;
  }
}
