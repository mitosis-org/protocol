// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { VotesUpgradeable } from '@ozu-v5/governance/utils/VotesUpgradeable.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { ERC20VotesUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20VotesUpgradeable.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../lib/LibRedeemQueue.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): Consider to support EIP-2612
// TODO(thai): Add more view functions. (Check ReclaimQueueStorageV1.sol as a reference)

contract GovMITO is IGovMITO, ERC20VotesUpgradeable, Ownable2StepUpgradeable {
  using ERC7201Utils for string;
  using LibRedeemQueue for *;

  /// @custom:storage-location mitosis.storage.GovMITO
  struct GovMITOStorage {
    address minter;
    LibRedeemQueue.Queue redeemQueue;
    mapping(address sender => bool) isWhitelistedSender;
  }

  modifier onlyMinter() {
    require(_msgSender() == _getGovMITOStorage().minter, StdError.Unauthorized());
    _;
  }

  modifier onlyWhitelistedSender(address sender) {
    require(_getGovMITOStorage().isWhitelistedSender[sender], StdError.Unauthorized());
    _;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.GovMITO';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getGovMITOStorage() private view returns (GovMITOStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    revert StdError.Unauthorized();
  }

  receive() external payable {
    revert StdError.Unauthorized();
  }

  function initialize(address _owner, address minter_, uint256 redeemPeriod_) external initializer {
    // TODO(thai): not fixed yet. could be modified before launching.
    __ERC20_init('Mitosis Governance Token', 'gMITO');
    __Ownable2Step_init();
    _transferOwnership(_owner);

    GovMITOStorage storage $ = _getGovMITOStorage();

    _setMinter($, minter_);
    _setRedeemPeriod($, redeemPeriod_);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function minter() external view returns (address) {
    return _getGovMITOStorage().minter;
  }

  function isWhitelistedSender(address sender) external view returns (bool) {
    return _getGovMITOStorage().isWhitelistedSender[sender];
  }

  function redeemPeriod() external view returns (uint256) {
    return _getGovMITOStorage().redeemQueue.redeemPeriod;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function mint(address to, uint256 amount) external payable onlyMinter {
    require(msg.value == amount, StdError.InvalidParameter('amount'));
    _mint(to, amount);
    emit Minted(to, amount);
  }

  function requestRedeem(address receiver, uint256 amount) external returns (uint256 reqId) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    _burn(_msgSender(), amount);
    reqId = $.redeemQueue.enqueue(receiver, amount, amount, clock());
    $.redeemQueue.reserve(amount, amount, totalSupply(), totalSupply(), clock());

    emit RedeemRequested(_msgSender(), receiver, amount);

    return reqId;
  }

  function claimRedeem(address receiver) external returns (uint256 claimed) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    $.redeemQueue.update(clock());
    claimed = $.redeemQueue.claim(receiver, clock());

    SafeTransferLib.safeTransferETH(receiver, claimed);

    emit RedeemRequestClaimed(receiver, claimed);

    return claimed;
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function setMinter(address minter_) external onlyOwner {
    _setMinter(_getGovMITOStorage(), minter_);
  }

  function setWhitelistedSender(address sender, bool isWhitelisted) external onlyOwner {
    _setWhitelistedSender(_getGovMITOStorage(), sender, isWhitelisted);
  }

  // ============================ NOTE: IERC6372 OVERRIDES ============================ //

  function clock() public view override(IERC6372, VotesUpgradeable) returns (uint48) {
    return Time.timestamp();
  }

  function CLOCK_MODE() public view override(IERC6372, VotesUpgradeable) returns (string memory) {
    // Check that the clock was not modified
    require(clock() == Time.timestamp(), ERC6372InconsistentClock());
    return 'mode=timestamp';
  }

  // =========================== NOTE: ERC20 OVERRIDES =========================== //

  function approve(address spender, uint256 amount)
    public
    override(IERC20, ERC20Upgradeable)
    onlyWhitelistedSender(_msgSender())
    returns (bool)
  {
    return super.approve(spender, amount);
  }

  function transfer(address to, uint256 amount)
    public
    override(IERC20, ERC20Upgradeable)
    onlyWhitelistedSender(_msgSender())
    returns (bool)
  {
    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 amount)
    public
    override(IERC20, ERC20Upgradeable)
    onlyWhitelistedSender(from)
    returns (bool)
  {
    return super.transferFrom(from, to, amount);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //
  function _setMinter(GovMITOStorage storage $, address minter_) internal {
    $.minter = minter_;
    emit MinterSet(minter_);
  }

  function _setWhitelistedSender(GovMITOStorage storage $, address sender, bool isWhitelisted) internal {
    $.isWhitelistedSender[sender] = isWhitelisted;
    emit WhiltelistedSenderSet(sender, isWhitelisted);
  }

  function _setRedeemPeriod(GovMITOStorage storage $, uint256 redeemPeriod_) internal {
    $.redeemQueue.redeemPeriod = redeemPeriod_;
    emit RedeemPeriodSet(redeemPeriod_);
  }
}
