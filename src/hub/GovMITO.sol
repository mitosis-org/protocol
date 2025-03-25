// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';
import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { ReentrancyGuardTransient } from '@oz-v5/utils/ReentrancyGuardTransient.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { VotesUpgradeable } from '@ozu-v5/governance/utils/VotesUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { ERC20PermitUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import { ERC20VotesUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../lib/LibRedeemQueue.sol';
import { StdError } from '../lib/StdError.sol';
import { SudoVotes } from '../lib/SudoVotes.sol';

// TODO(thai): Add more view functions. (Check ReclaimQueueStorageV1.sol as a reference)
contract GovMITO is
  IGovMITO,
  ERC20PermitUpgradeable,
  ERC20VotesUpgradeable,
  Ownable2StepUpgradeable,
  UUPSUpgradeable,
  SudoVotes,
  ReentrancyGuardTransient
{
  using ERC7201Utils for string;
  using LibRedeemQueue for *;
  using SafeCast for uint256;

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
    revert StdError.NotSupported();
  }

  receive() external payable {
    revert StdError.NotSupported();
  }

  function initialize(address owner_, address minter_, uint256 redeemPeriod_) external initializer {
    require(owner_ != address(0), StdError.ZeroAddress('owner'));
    require(minter_ != address(0), StdError.ZeroAddress('minter'));
    require(redeemPeriod_ > 0, StdError.InvalidParameter('redeemPeriod'));

    // TODO(thai): not fixed yet. could be modified before launching.
    __ERC20_init('Mitosis Governance Token', 'gMITO');
    __ERC20Permit_init('Mitosis Governance Token');
    __ERC20Votes_init();

    __Ownable2Step_init();
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();

    GovMITOStorage storage $ = _getGovMITOStorage();

    _setMinter($, minter_);
    _setRedeemPeriod($, redeemPeriod_);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function owner() public view override(OwnableUpgradeable, SudoVotes) returns (address) {
    return super.owner();
  }

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

  function delegate(address delegatee) public pure override(IVotes, VotesUpgradeable, SudoVotes) {
    super.delegate(delegatee);
  }

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
    public
    pure
    override(IVotes, VotesUpgradeable, SudoVotes)
  {
    super.delegateBySig(delegatee, nonce, expiry, v, r, s);
  }

  function mint(address to) external payable onlyMinter {
    require(msg.value > 0, StdError.ZeroAmount());
    _mint(to, msg.value);
    emit Minted(to, msg.value);
  }

  function requestRedeem(address receiver, uint256 amount) external returns (uint256 reqId) {
    require(receiver != address(0), StdError.ZeroAddress('receiver'));
    require(amount > 0, StdError.ZeroAmount());

    GovMITOStorage storage $ = _getGovMITOStorage();

    _burn(_msgSender(), amount);
    reqId = $.redeemQueue.enqueue(receiver, amount, clock(), bytes(''));
    $.redeemQueue.reserve(address(this), amount, clock(), bytes(''));

    emit RedeemRequested(_msgSender(), receiver, amount);

    return reqId;
  }

  function claimRedeem(address receiver) external nonReentrant returns (uint256 claimed) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    $.redeemQueue.update(clock());
    claimed = $.redeemQueue.claim(receiver, clock());

    SafeTransferLib.safeTransferETH(receiver, claimed);

    emit RedeemRequestClaimed(receiver, claimed);

    return claimed;
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function setMinter(address minter_) external onlyOwner {
    require(minter_ != address(0), StdError.ZeroAddress('minter'));
    _setMinter(_getGovMITOStorage(), minter_);
  }

  function setWhitelistedSender(address sender, bool isWhitelisted) external onlyOwner {
    require(sender != address(0), StdError.ZeroAddress('sender'));
    _setWhitelistedSender(_getGovMITOStorage(), sender, isWhitelisted);
  }

  function setRedeemPeriod(uint256 redeemPeriod_) external onlyOwner {
    require(redeemPeriod_ > 0, StdError.InvalidParameter('redeemPeriod'));
    _setRedeemPeriod(_getGovMITOStorage(), redeemPeriod_);
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

  function approve(address spender, uint256 amount) public override(IERC20, ERC20Upgradeable) returns (bool) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    require($.isWhitelistedSender[_msgSender()], StdError.Unauthorized());

    return super.approve(spender, amount);
  }

  function transfer(address to, uint256 amount) public override(IERC20, ERC20Upgradeable) returns (bool) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    require($.isWhitelistedSender[_msgSender()], StdError.Unauthorized());

    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 amount)
    public
    override(IERC20, ERC20Upgradeable)
    returns (bool)
  {
    GovMITOStorage storage $ = _getGovMITOStorage();

    require($.isWhitelistedSender[from], StdError.Unauthorized());

    return super.transferFrom(from, to, amount);
  }

  function nonces(address owner_) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
    return super.nonces(owner_);
  }

  function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
    super._update(from, to, amount);
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
