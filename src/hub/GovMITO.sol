// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { ERC20Upgradeable } from '@ozu-v5/token/ERC20/ERC20Upgradeable.sol';
import { ERC20VotesUpgradeable } from '@ozu-v5/token/ERC20/extensions/ERC20VotesUpgradeable.sol';

import { SafeTransferLib } from '@solady/utils/SafeTransferLib.sol';

import { IGovMITO } from '../interfaces/hub/IGovMITO.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract GovMITO is IGovMITO, ERC20VotesUpgradeable, Ownable2StepUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.MatrixVaultCapped
  struct GovMITOStorage {
    address minter;
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

  function initialize(address _owner, string calldata name, string calldata symbol, address minter_)
    external
    initializer
  {
    __ERC20_init(name, symbol);
    __Ownable2Step_init();
    _transferOwnership(_owner);

    _getGovMITOStorage().minter = minter_;
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function minter() external view returns (address) {
    return _getGovMITOStorage().minter;
  }

  function isWhitelistedSender(address sender) external view returns (bool) {
    return _getGovMITOStorage().isWhitelistedSender[sender];
  }

  // ============================ NOTE: MUTATIVE FUNCTIONS ============================ //

  function mint(address to, uint256 amount) external payable onlyMinter {
    require(msg.value == amount, StdError.InvalidParameter('amount'));
    _mint(to, amount);
    emit Minted(to, amount);
  }

  function redeem(address to, uint256 amount) external {
    _burn(_msgSender(), amount);
    SafeTransferLib.safeTransferETH(to, amount);
    emit Redeemed(_msgSender(), to, amount);
  }

  // ============================ NOTE: OWNABLE FUNCTIONS ============================ //

  function setMinter(address minter_) external onlyOwner {
    _getGovMITOStorage().minter = minter_;
  }

  function setWhitelistedSender(address sender, bool isWhitelisted) external onlyOwner {
    _getGovMITOStorage().isWhitelistedSender[sender] = isWhitelisted;
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
}
