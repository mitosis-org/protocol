// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Arrays {
  function exists(address[] memory arr, address element) internal pure returns (bool) {
    uint256 length = arr.length;
    for (uint256 i = 0; i < length; i++) {
      if (arr[i] == element) return true;
    }
    return false;
  }

  function exists(uint256[] memory arr, uint256 element) internal pure returns (bool) {
    uint256 length = arr.length;
    for (uint256 i = 0; i < length; i++) {
      if (arr[i] == element) return true;
    }
    return false;
  }

  function exists(uint32[] memory arr, uint32 element) internal pure returns (bool) {
    uint256 length = arr.length;
    for (uint256 i = 0; i < length; i++) {
      if (arr[i] == element) return true;
    }
    return false;
  }
}
