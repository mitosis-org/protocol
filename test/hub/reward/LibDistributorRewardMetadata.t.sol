// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
  LibDistributorRewardMetadata,
  RewardMerkleMetadata,
  RewardTWABMetadata
} from '../../../src/hub/reward/LibDistributorRewardMetadata.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract Decoder {
  function decodeRewardTWABMetadata(bytes calldata enc) public pure returns (RewardTWABMetadata memory metadata) {
    metadata = LibDistributorRewardMetadata.decodeRewardTWABMetadata(enc);
    return metadata;
  }

  function decodeRewardMerkleMetadata(bytes calldata enc) public pure returns (RewardMerkleMetadata memory metadata) {
    metadata = LibDistributorRewardMetadata.decodeRewardMerkleMetadata(enc);
    return metadata;
  }
}

contract LibDistributorRewardMetadataTest is Toolkit {
  using LibDistributorRewardMetadata for *;

  Decoder internal _dec;

  function setUp() public {
    _dec = new Decoder();
  }

  function test_encode_merkle() public {
    RewardMerkleMetadata memory metadata = RewardMerkleMetadata({ stage: 1, amount: 10 ether, proof: new bytes32[](3) });
    metadata.proof[0] = keccak256(abi.encode(1));
    metadata.proof[1] = keccak256(abi.encode(2));
    metadata.proof[2] = keccak256(abi.encode(3));

    bytes memory enc = metadata.encode();
    RewardMerkleMetadata memory decoded = _dec.decodeRewardMerkleMetadata(enc);

    assertEq(decoded.stage, metadata.stage);
    assertEq(decoded.amount, metadata.amount);
    assertEq(decoded.proof.length, metadata.proof.length);
    assertEq(decoded.proof, metadata.proof);
  }

  function test_encode_merkleInvalidLength() public {
    RewardMerkleMetadata memory metadata = RewardMerkleMetadata({ stage: 1, amount: 10 ether, proof: new bytes32[](3) });
    metadata.proof[0] = keccak256(abi.encode(1));
    metadata.proof[1] = keccak256(abi.encode(2));
    metadata.proof[2] = keccak256(abi.encode(3));

    bytes memory enc = metadata.encode();

    vm.expectRevert(_errInvalidMsgLength(enc.length + bytes('hello').length, enc.length));
    _dec.decodeRewardMerkleMetadata(abi.encodePacked(enc, bytes('hello')));
  }

  function test_encode_twab() public {
    RewardTWABMetadata memory metadata = RewardTWABMetadata({ batchTimestamp: 1 });

    bytes memory enc = metadata.encode();
    RewardTWABMetadata memory decoded = _dec.decodeRewardTWABMetadata(enc);

    assertEq(decoded.batchTimestamp, metadata.batchTimestamp);
  }

  function test_encode_twabInvalidLength() public {
    RewardTWABMetadata memory metadata = RewardTWABMetadata({ batchTimestamp: 1 });

    bytes memory enc = metadata.encode();

    vm.expectRevert(_errInvalidMsgLength(enc.length + bytes('hello').length, enc.length));
    _dec.decodeRewardTWABMetadata(abi.encodePacked(enc, bytes('hello')));
  }

  function _errInvalidMsgLength(uint256 actual, uint256 expected) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      LibDistributorRewardMetadata.LibDistributorRewardMetadata__InvalidMsgLength.selector, actual, expected
    );
  }
}
