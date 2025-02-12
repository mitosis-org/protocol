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
   * @notice Emitted when a redeem request is made.
   * @param requester The address that made the request
   * @param receiver The address that will receive the assets
   * @param amount The amount of tokens to redeem
   */
  event RedeemRequested(address indexed requester, address indexed receiver, uint256 amount);

  /**
   * @notice Emitted when a redeem request is claimed.
   * @param receiver The address that received the assets
   * @param claimed The amount of assets claimed
   */
  event RedeemRequestClaimed(address indexed receiver, uint256 claimed);

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
   * @notice Emitted when the redeem period is set.
   * @param redeemPeriod The new redeem period
   */
  event RedeemPeriodSet(uint256 redeemPeriod);

  /**
   * @notice Mint tokens to an address with corresponding MITO.
   * @dev Only the minter can call this function.
   * @param to The address to mint tokens to
   * @param amount The amount of tokens to mint
   */
  function mint(address to, uint256 amount) external payable;

  /**
   * @notice Request to redeem tokens for assets.
   * @dev The requester must have enough tokens to redeem.
   * @param receiver The address to receive the assets
   * @param amount The amount of tokens to redeem
   * @return reqId The ID of the redeem request
   */
  function requestRedeem(address receiver, uint256 amount) external returns (uint256 reqId);

  /**
   * @notice Claim a redeem request.
   * @dev The receiver must have a redeem request to claim.
   * @param receiver The address to claim the redeem request for
   * @return claimed The amount of assets claimed
   */
  function claimRedeem(address receiver) external returns (uint256 claimed);
}
