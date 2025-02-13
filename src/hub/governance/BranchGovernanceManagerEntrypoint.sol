// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { GasRouter } from '@hpl-v5/client/GasRouter.sol';
import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { Address } from '@oz-v5/utils/Address.sol';

import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import '../../message/Message.sol';
import { BranchGovernanceManager } from './BranchGovernanceManager.sol';

contract BranchGovernanceManagerEntrypoint is IMessageRecipient, GasRouter, Ownable2StepUpgradeable {
  using Message for *;
  using Conv for *;

  BranchGovernanceManager internal immutable _branchGovernanceManager;
  ICrossChainRegistry internal immutable _ccRegistry;

  modifier onlyBranchGovernanceManager() {
    require(_msgSender() == address(_branchGovernanceManager), StdError.InvalidAddress('BranchGovernanceManager'));
    _;
  }

  modifier onlyDispatchable(uint256 chainId) {
    require(_ccRegistry.isRegisteredChain(chainId), ICrossChainRegistry.ICrossChainRegistry__NotRegistered());
    require(
      _ccRegistry.governanceExecutorEntrypointEnrolled(chainId),
      ICrossChainRegistry.ICrossChainRegistry__GovernanceExecutorEntrypointNotEnrolled()
    );
    _;
  }

  constructor(address mailbox, address branchGovernanceManager_, address ccRegistry_) GasRouter(mailbox) initializer {
    _branchGovernanceManager = BranchGovernanceManager(branchGovernanceManager_);
    _ccRegistry = ICrossChainRegistry(ccRegistry_);
  }

  function initialize(address owner_, address hook, address ism) public initializer {
    _MailboxClient_initialize(hook, ism, owner_);
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  receive() external payable { }

  function dispatchGovernanceExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external onlyBranchGovernanceManager onlyDispatchable(chainId) {
    bytes memory enc = MsgDispatchMITOGovernanceExecution({
      targets: _convertAddressArrayToBytes32Array(targets),
      values: values,
      data: data
    }).encode();
    _dispatchToBranch(chainId, enc);
  }

  function _dispatchToBranch(uint256 chainId, bytes memory enc) internal {
    uint32 hplDomain = _ccRegistry.hyperlaneDomain(chainId);

    uint256 fee = _GasRouter_quoteDispatch(hplDomain, enc, address(hook));
    _GasRouter_dispatch(hplDomain, fee, enc, address(hook));
  }

  // tmp
  function _convertAddressArrayToBytes32Array(address[] calldata arr) internal returns (bytes32[] memory addressed) {
    addressed = new bytes32[](addresses.length);
    for (uint256 i = 0; i < addresses.length; i++) {
      addressed = arr[i].toBytes32();
    }
  }

  //=========== NOTE: ROUTER OVERRIDES ============//

  function enrollRemoteRouter(uint32 domain_, bytes32 router_) external override {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    _enrollRemoteRouter(domain_, router_);
  }

  function enrollRemoteRouters(uint32[] calldata domain_, bytes32[] calldata addresses_) external override {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    require(domain_.length == addresses_.length, '!length');
    uint256 length = domain_.length;
    for (uint256 i = 0; i < length; i += 1) {
      _enrollRemoteRouter(domain_[i], addresses_[i]);
    }
  }

  function unenrollRemoteRouter(uint32 domain_) external override {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    _unenrollRemoteRouter(domain_);
  }

  function unenrollRemoteRouters(uint32[] calldata domains_) external override {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    uint256 length = domains_.length;
    for (uint256 i = 0; i < length; i += 1) {
      _unenrollRemoteRouter(domains_[i]);
    }
  }

  function setDestGas(GasRouterConfig[] calldata gasConfigs) external {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    for (uint256 i = 0; i < gasConfigs.length; i += 1) {
      _setDestinationGas(gasConfigs[i].domain, gasConfigs[i].gas);
    }
  }

  function setDestGas(uint32 domain, uint256 gas) external {
    require(_msgSender() == owner() || _msgSender() == address(_ccRegistry), StdError.Unauthorized());
    _setDestinationGas(domain, gas);
  }

  //=========== NOTE: OwnableUpgradeable & Ownable2StepUpgradeable

  function transferOwnership(address owner) public override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable.transferOwnership(owner);
  }

  function _transferOwnership(address owner) internal override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    Ownable2StepUpgradeable._transferOwnership(owner);
  }
}
