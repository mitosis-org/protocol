// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { IERC6372 } from '@oz-v5/interfaces/IERC6372.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { VotesUpgradeable } from '@ozu-v5/governance/utils/VotesUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { ERC20PermitUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import { ERC20VotesUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20VotesUpgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { LibRedeemQueue } from '../lib/LibRedeemQueue.sol';
import { StdError } from '../lib/StdError.sol';

// TODO(thai): Add more view functions. (Check ReclaimQueueStorageV1.sol as a reference)

contract GovMITO is IGovMITO, ERC20PermitUpgradeable, ERC20VotesUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
  using ERC7201Utils for string;
  using LibRedeemQueue for *;

  /// @custom:storage-location mitosis.storage.GovMITO
  struct GovMITOStorage {
    address minter;
    LibRedeemQueue.Queue redeemQueue;
    mapping(address sender => bool) isProxied;
    mapping(address account => uint256) proxiedBalances;
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

  function minter() external view returns (address) {
    return _getGovMITOStorage().minter;
  }

  function isWhitelistedSender(address sender) external view returns (bool) {
    return _getGovMITOStorage().isWhitelistedSender[sender];
  }

  function isProxied(address sender) external view returns (bool) {
    return _getGovMITOStorage().isProxied[sender];
  }

  function proxiedBalances(address account) external view returns (uint256) {
    return _getGovMITOStorage().proxiedBalances[account];
  }

  function redeemPeriod() external view returns (uint256) {
    return _getGovMITOStorage().redeemQueue.redeemPeriod;
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function mint(address to) external payable onlyMinter {
    require(msg.value > 0, StdError.ZeroAmount());
    _mint(to, msg.value);
    emit Minted(to, msg.value);
  }

  function requestRedeem(address receiver, uint256 amount) external returns (uint256 reqId) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    _burn(_msgSender(), amount);
    reqId = $.redeemQueue.enqueue(receiver, amount, clock(), bytes(''));
    $.redeemQueue.reserve(address(this), amount, clock(), bytes(''));

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

  // ============================ NOTE: PROXY FUNCTIONS ============================ //

  function _getVotingUnits(address account) internal view override returns (uint256) {
    return super._getVotingUnits(account) + _getGovMITOStorage().proxiedBalances[account];
  }

  function notifyProxiedDeposit(address sender, uint256 amount) external {
    GovMITOStorage storage $ = _getGovMITOStorage();
    require($.isProxied[_msgSender()], StdError.Unauthorized());

    $.proxiedBalances[sender] += amount;
    _transferVotingUnits(_msgSender(), sender, amount);

    emit ProxiedDepositNotified(_msgSender(), sender, amount);
  }

  function notifyProxiedWithdraw(address sender, uint256 amount) external {
    GovMITOStorage storage $ = _getGovMITOStorage();
    require($.isProxied[_msgSender()], StdError.Unauthorized());

    $.proxiedBalances[sender] -= amount;
    _transferVotingUnits(sender, _msgSender(), amount);

    emit ProxiedWithdrawNotified(_msgSender(), sender, amount);
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function _authorizeUpgrade(address) internal override onlyOwner { }

  function setMinter(address minter_) external onlyOwner {
    _setMinter(_getGovMITOStorage(), minter_);
  }

  function setWhitelistedSender(address sender, bool isWhitelisted) external onlyOwner {
    _setWhitelistedSender(_getGovMITOStorage(), sender, isWhitelisted);
  }

  function setProxied(address sender, bool isProxied_) external onlyOwner {
    _setProxied(_getGovMITOStorage(), sender, isProxied_);
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

    require($.isProxied[spender] || $.isWhitelistedSender[_msgSender()], StdError.Unauthorized());

    return super.approve(spender, amount);
  }

  function transfer(address to, uint256 amount) public override(IERC20, ERC20Upgradeable) returns (bool) {
    GovMITOStorage storage $ = _getGovMITOStorage();

    require($.isProxied[_msgSender()] || $.isWhitelistedSender[_msgSender()], StdError.Unauthorized());

    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 amount)
    public
    override(IERC20, ERC20Upgradeable)
    returns (bool)
  {
    GovMITOStorage storage $ = _getGovMITOStorage();

    require($.isProxied[_msgSender()] || $.isWhitelistedSender[_msgSender()], StdError.Unauthorized());

    return super.transferFrom(from, to, amount);
  }

  function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
    return super.nonces(owner);
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

  function _setProxied(GovMITOStorage storage $, address sender, bool isProxied_) internal {
    $.isProxied[sender] = isProxied_;
    emit SetProxy(sender, isProxied_);
  }

  function _setRedeemPeriod(GovMITOStorage storage $, uint256 redeemPeriod_) internal {
    $.redeemQueue.redeemPeriod = redeemPeriod_;
    emit RedeemPeriodSet(redeemPeriod_);
  }
}
