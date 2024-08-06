// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { ICrossChainRegistry } from '../interfaces/cross-chain/ICrossChainRegistry.sol';
import { KVContainer } from '../lib/KVContainer.sol';
import { Error } from '../lib/Error.sol';
import { MsgType } from './messages/Message.sol';

contract CrossChainRegistryStorageV1 {
  struct StorageV1 {
    KVContainer kvContainer;
    uint256[] chains;
  }

  bytes32 public constant WRITER_ROLE = keccak256('WRITER_ROLE');

  // keccak256(abi.encode(uint256(keccak256("mitosis-protocol.storage.CrossChainRegistryStorageV1.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0x5df85134e0cd615622b98ff98ced84d19d412f4c64e5a4bd5c374ebc77026200;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}

contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  event ChainSet(uint256 indexed chain, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chain, address indexed vault, address indexed underlyingAsset);
  event HyperlaneRouteSet(uint32 indexed hplDomain, bytes1 indexed msgType, address indexed dest);

  constructor(address kvContainer) initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _getStorageV1().kvContainer = KVContainer(kvContainer);
  }

  //=========== merge OwnableUpgradeable & Ownable2StepUpgradeable

  function transferOwnership(address owner) public override {
    Ownable2StepUpgradeable.transferOwnership(owner);
  }

  function _transferOwnership(address owner) internal override {
    Ownable2StepUpgradeable._transferOwnership(owner);
  }

  //===========

  function initialize(address owner) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
  }

  modifier onlyAdmin() {
    _checkRole(DEFAULT_ADMIN_ROLE);
    _;
  }

  modifier onlyWriter() {
    _checkRole(WRITER_ROLE);
    _;
  }

  modifier onlyRegisteredChain(uint256 chain) {
    if (!_checkChainAlreadyRegistered(chain)) {
      revert Error.NotRegistered();
    }
    _;
  }

  // View functions

  function getChains() public view returns (uint256[] memory) {
    return _getStorageV1().chains;
  }

  function getChainName(uint256 chain) public view returns (string memory) {
    bytes32 key = _getChainNameKey(chain);
    return _getStorageV1().kvContainer.getString(key);
  }

  function getHyperlaneDomain(uint256 chain) public view returns (uint32) {
    bytes32 key = _getHyperlaneDomainKey(chain);
    return uint32(_getStorageV1().kvContainer.getUint(key));
  }

  function getVault(uint256 chain, address asset) public view returns (address) {
    bytes32 key = _getVaultKey(chain, asset);
    return _getStorageV1().kvContainer.getAddress(key);
  }

  function getVaultUnderlyingAsset(uint256 chain, address vault) public view returns (address) {
    bytes32 key = _getVaultUnderlyingAssetKey(chain, vault);
    return _getStorageV1().kvContainer.getAddress(key);
  }

  function getChainByHyperlaneDomain(uint32 hplDomain) public view returns (uint256) {
    bytes32 key = _getChainByHyperlaneDomainKey(hplDomain);
    return _getStorageV1().kvContainer.getUint(key);
  }

  function getHyperlaneRoute(uint32 hplDomain, MsgType msgType) public view returns (address) {
    bytes32 key = _getHyperlaneRouteKey(hplDomain, msgType);
    return _getStorageV1().kvContainer.getAddress(key);
  }

  // Mutative functions
  //
  // TODO: update methods

  function changeAdmin(address newAdmin) public onlyAdmin {
    // AccessControl emit event `RoleAdminChanged`
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, bytes32(uint256(uint160(newAdmin))));
  }

  function grantWriter(address target) public onlyAdmin {
    // AccessControl emit event `RoleGranted`
    grantRole(WRITER_ROLE, target);
  }

  function revokeWriter(address target) public onlyAdmin {
    // AccessControl emit event `RoleRevoked`
    revokeRole(WRITER_ROLE, target);
  }

  function setChain(uint256 chain, string calldata name, uint32 hplDomain) public onlyWriter {
    if (_checkChainAlreadyRegistered(chain)) {
      revert Error.AlreadyRegistered();
    }
    StorageV1 storage $ = _getStorageV1();
    $.chains.push(chain);

    KVContainer container = $.kvContainer;
    container.setString(_getChainNameKey(chain), name);
    container.setUint(_getHyperlaneDomainKey(chain), hplDomain);
    container.setUint(_getChainByHyperlaneDomainKey(hplDomain), chain);
    emit ChainSet(chain, hplDomain, name);
  }

  function setVault(uint256 chain, address vault, address underlyingAsset) public onlyWriter onlyRegisteredChain(chain) {
    KVContainer container = _getStorageV1().kvContainer;
    container.setAddress(_getVaultKey(chain, underlyingAsset), vault);
    container.setAddress(_getVaultUnderlyingAssetKey(chain, vault), underlyingAsset);
    emit VaultSet(chain, vault, underlyingAsset);
  }

  function setHyperlaneRoute(uint32 hplDomain, MsgType msgType, address dest) external onlyWriter {
    uint256 chain = getChainByHyperlaneDomain(hplDomain);
    if (chain == 0) revert Error.NotRegistered();
    KVContainer container = _getStorageV1().kvContainer;
    container.setAddress(_getHyperlaneRouteKey(hplDomain, msgType), dest);
    emit HyperlaneRouteSet(hplDomain, bytes1(uint8(msgType)), dest);
  }

  // Internal functions
  //
  // Keys
  function _getChainNameKey(uint256 chain) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('chain', chain, '.name'));
  }

  function _getHyperlaneDomainKey(uint256 chain) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('chain', chain, '.domains', '.hyperlane'));
  }

  function _getVaultKey(uint256 chain, address asset) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('chain', chain, '.vaults', asset));
  }

  function _getVaultUnderlyingAssetKey(uint256 chain, address vault) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('chain', chain, vault, '.underlying'));
  }

  function _getStrategyExecutorKey(address eolVault, uint256 executorId, uint256 chain) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('eol_vault', eolVault, '.strategy_executors', executorId, chain));
  }

  function _getChainByHyperlaneDomainKey(uint32 hplDomain) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('hyperlane_domain', hplDomain, '.chain_id'));
  }

  function _getHyperlaneRouteKey(uint32 hplDomain, MsgType msgType) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('hyperlane_domain', hplDomain, '.routes', msgType));
  }

  function _checkChainAlreadyRegistered(uint256 chain) internal view returns (bool) {
    uint256[] memory chains = _getStorageV1().chains;
    for (uint256 i = 0; i < chains.length; i++) {
      if (chain == chains[i]) {
        return true;
      }
    }
    return false;
  }
}
