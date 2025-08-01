// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { BaseDecoderAndSanitizer } from './BaseDecoderAndSanitizer.sol';

contract ManagerDecoderAndSanitizer is BaseDecoderAndSanitizer {
  function deposit(address asset, uint256) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(asset);
  }

  function withdraw(address asset, uint256, address receiver) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(asset, receiver);
  }
}
