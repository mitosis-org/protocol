// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibString } from 'solady/utils/LibString.sol';

contract Placeholder {
  using LibString for string;

  function say(string memory ask) external pure returns (string memory) {
    return ask.repeat(3);
  }
}
