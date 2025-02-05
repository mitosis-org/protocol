// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Snapshots } from '../../twab/IERC20Snapshots.sol';

/**
 * @title IHubAsset
 * @dev Common interface for {HubAsset}. Extends IERC20Snapshots with minting and burning capabilities.
 */
interface IHubAsset is IERC20Snapshots {
  /**
   * @notice Mints new tokens to a specified account.
   * @dev This function should only be callable by authorized entities.
   * @param account The address of the account to receive the minted tokens.
   * @param value The amount of tokens to mint.
   */
  function mint(address account, uint256 value) external;

  /**
   * @notice Burns tokens from a specified account.
   * @dev This function should only be callable by authorized entities.
   * @param account The address of the account from which tokens will be burned.
   * @param value The amount of tokens to burn.
   */
  function burn(address account, uint256 value) external;
}
