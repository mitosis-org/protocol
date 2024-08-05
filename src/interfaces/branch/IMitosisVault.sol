// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
pragma abicoder v2;

interface IMitosisVault {
  function owner() external view returns (address);

  function useEOL(address asset, uint256 amount) external;

  function returnEOL(address asset, uint256 amount) external;
}
