// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library StdError {
  error Halted();
  error Unauthorized();
  error NotFound(string typ);
  error NotImplemented();

  error InvalidId(string typ);
  error InvalidAddress(string typ);
  error ZeroAmount();
  error ZeroAddress(string typ);
}
