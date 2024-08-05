// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMitosisVaultEntrypoint {
  function mint(address asset, address to, uint256 amount) external;
}
