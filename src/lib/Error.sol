// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

library Error {
  error Halted();
  error Unauthorized();
  error NotFound(string typ);
  error NotImplemented();

  error InvalidId(string typ);
  error InvalidAddress(string typ);
  error ZeroAmount();
}
