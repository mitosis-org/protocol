// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { GasRouter } from '@hpl-v5/client/GasRouter.sol';
import { IMessageRecipient } from '@hpl-v5/interfaces/IMessageRecipient.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { Address } from '@oz-v5/utils/Address.sol';

import { ICrossChainRegistry } from '../../interfaces/hub/cross-chain/ICrossChainRegistry.sol';
import { IBranchGovernanceEntrypoint } from
  '../../interfaces/hub/governance/IBranchGovernanceEntrypoint.sol';
import { Conv } from '../../lib/Conv.sol';
import { StdError } from '../../lib/StdError.sol';
import '../../message/Message.sol';

contract BranchGovernanceEntrypoint is
  IBranchGovernanceEntrypoint,
  GasRouter,
  UUPSUpgradeable,
  AccessControlUpgradeable
{
  using Message for *;
  using Conv for *;

  /// @notice Role for manager (keccak256("MANAGER_ROLE"))
  bytes32 public constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;

  ICrossChainRegistry internal immutable _ccRegistry;

  modifier onlyDispatchable(uint256 chainId) {
    require(_ccRegistry.isRegisteredChain(chainId), ICrossChainRegistry.ICrossChainRegistry__NotRegistered());
    require(
      _ccRegistry.governanceExecutorEntrypointEnrolled(chainId),
      ICrossChainRegistry.ICrossChainRegistry__GovernanceExecutorEntrypointNotEnrolled()
    );
    _;
  }

  constructor(address mailbox, address ccRegistry_) GasRouter(mailbox) initializer {
    _ccRegistry = ICrossChainRegistry(ccRegistry_);
  }

  function initialize(address owner_, address[] memory managers, address hook, address ism) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _MailboxClient_initialize(hook, ism, owner_);

    for (uint256 i = 0; i < managers.length; i++) {
      _grantRole(MANAGER_ROLE, managers[i]);
    }
  }

  receive() external payable { }

  function dispatchGovernanceExecution(
    uint256 chainId,
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
  ) external onlyRole(MANAGER_ROLE) onlyDispatchable(chainId) {
    bytes memory enc = MsgDispatchGovernanceExecution({
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

  function _handle(uint32, bytes32, bytes calldata) internal override { }

  function _convertAddressArrayToBytes32Array(address[] calldata arr)
    internal
    pure
    returns (bytes32[] memory addressed)
  {
    addressed = new bytes32[](arr.length);
    for (uint256 i = 0; i < arr.length; i++) {
      addressed[i] = arr[i].toBytes32();
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

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(MANAGER_ROLE) { }
}
