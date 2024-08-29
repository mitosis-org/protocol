// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct TWABHandleRewardhMetadata {
  address erc20TwabSnapshots;
  uint48 timestamp;
}

library DistributorHandleRewardMetadataLib {
  error DistributorHandleRewardMetadataLib__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(TWABHandleRewardhMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.erc20TwabSnapshots, metadata.timestamp);
  }

  function decodeTWABHandleRewardhMetadata(bytes memory enc)
    internal
    pure
    returns (TWABHandleRewardhMetadata memory metadata)
  {
    if (enc.length != 28) revert DistributorHandleRewardMetadataLib__InvalidMsgLength(enc.length, 28);

    (address erc20TwabSnapshots, uint48 timestamp) = abi.decode(enc, (address, uint48));

    metadata.erc20TwabSnapshots = erc20TwabSnapshots;
    metadata.timestamp = timestamp;
  }
}
