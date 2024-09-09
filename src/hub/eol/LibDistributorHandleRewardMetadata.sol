// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

struct HandleRewardTWABMetadata {
  address erc20TWABSnapshots;
  uint48 timestamp;
}

library LibDistributorHandleRewardMetadata {
  error LibDistributorHandleRewardMetadata__InvalidMsgLength(uint256 actual, uint256 expected);

  function encode(HandleRewardTWABMetadata memory metadata) internal pure returns (bytes memory) {
    return abi.encodePacked(metadata.erc20TWABSnapshots, metadata.timestamp);
  }

  function decodeHandleRewardTWABMetadata(bytes calldata enc)
    internal
    pure
    returns (HandleRewardTWABMetadata memory metadata)
  {
    require(enc.length == 26, LibDistributorHandleRewardMetadata__InvalidMsgLength(enc.length, 26));

    metadata.erc20TWABSnapshots = address(bytes20(enc[0:20]));
    metadata.timestamp = uint48(bytes6(enc[20:26]));
  }
}
