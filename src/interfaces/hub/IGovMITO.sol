// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC5805 } from '@oz-v5/interfaces/IERC5805.sol';

interface IGovMITO is IERC20, IERC5805 {
  /**
   * @notice Emitted when tokens are minted.
   * @param to The address that received the tokens
   * @param amount The amount of tokens minted
   */
  event Minted(address indexed to, uint256 amount);

  /**
   * @notice Emitted when tokens are redeemed.
   * @param from The address that redeemed the tokens
   * @param to The address that received MITO
   * @param amount The amount of tokens redeemed
   */
  event Redeemed(address indexed from, address indexed to, uint256 amount);

  /**
   * @notice Emitted when the minter is set.
   * @param minter The address of the new minter
   */
  event MinterSet(address indexed minter);

  /**
   * @notice Emitted when a whitelist status for a sender is set.
   * @param sender The address of the sender
   * @param whitelisted Whether the sender is whitelisted
   */
  event WhiltelistedSenderSet(address indexed sender, bool whitelisted);

  /**
   * @notice Mint tokens to an address with corresponding MITO.
   * @dev Only the minter can call this function.
   * @param to The address to mint tokens to
   * @param amount The amount of tokens to mint
   */
  function mint(address to, uint256 amount) external payable;

  /**
   * @notice Redeem tokens for MITO.
   * @param to The address to send MITO to
   * @param amount The amount of tokens to redeem
   */
  function redeem(address to, uint256 amount) external;
}
