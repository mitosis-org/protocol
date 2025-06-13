// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVersioned {
  function GIT_TAG() external view returns (string memory);

  function GIT_COMMIT() external view returns (string memory);
}
