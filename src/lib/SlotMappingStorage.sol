// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract SlotMappingStorage {
  function _getString(bytes32 key) internal view returns (string memory result) {
    bytes32 lengthKey = keccak256(abi.encodePacked(key, '.length'));
    assembly {
      result := mload(0x40)
      mstore(result, sload(lengthKey))
      mstore(add(result, 0x20), sload(key))
      mstore(0x40, add(result, 0x40))
    }
  }

  function _getUint32(bytes32 key) internal view returns (uint32 result) {
    assembly {
      result := sload(key)
    }
  }

  function _getAddress(bytes32 key) internal view returns (address result) {
    assembly {
      result := sload(key)
    }
  }

  function _getUint256(bytes32 key) internal view returns (uint256 result) {
    assembly {
      result := sload(key)
    }
  }

  function _setString(bytes32 key, string memory value) internal {
    bytes32 lengthKey = keccak256(abi.encodePacked(key, '.length'));
    assembly {
      sstore(lengthKey, mload(value))
      sstore(key, mload(add(value, 0x20)))
    }
  }

  function _setUint32(bytes32 key, uint32 value) internal {
    assembly {
      sstore(key, value)
    }
  }

  function _setAddress(bytes32 key, address value) internal {
    assembly {
      sstore(key, value)
    }
  }

  function _setUint256(bytes32 key, uint256 value) internal {
    assembly {
      sstore(key, value)
    }
  }
}
