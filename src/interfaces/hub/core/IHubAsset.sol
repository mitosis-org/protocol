// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20TWABSnapshots } from '../../twab/IERC20TWABSnapshots.sol';

/**
 * @title IHubAsset
 * @dev Common interface for {HubAsset}. Extends IERC20TWABSnapshots with minting and burning capabilities.
 */
interface IHubAsset is IERC20TWABSnapshots {
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
