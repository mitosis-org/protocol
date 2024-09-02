// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct HandleRewardTWABMetadata {
  address erc20TwabSnapshots;
  uint48 timestamp;
}

library DistributorHandleRewardMetadataLib {
  error DistributorHandleRewardMetadataLib__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(HandleRewardTWABMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.erc20TwabSnapshots, metadata.timestamp);
  }

  function decodeHandleRewardTWABMetadata(bytes calldata enc)
    internal
    pure
    returns (HandleRewardTWABMetadata memory metadata)
  {
    if (enc.length != 26) revert DistributorHandleRewardMetadataLib__InvalidMsgLength(enc.length, 26);

    metadata.erc20TwabSnapshots = address(bytes20(enc[0:20]));
    metadata.timestamp = uint48(bytes6(enc[20:26]));
  }
}
