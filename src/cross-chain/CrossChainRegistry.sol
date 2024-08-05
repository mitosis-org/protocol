// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AccessControl } from '@oz-v5/access/AccessControl.sol';
import { RegistryBase } from './RegistryBase.sol';
import { Storage } from '../lib/Storage.sol';
import { Error } from '../lib/Error.sol';
import { MsgType } from './messages/Message.sol';

contract CrossChainRegistry is RegistryBase, AccessControl {
  event ChainSet(uint256 indexed chain, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chain, address indexed vault, address indexed underlyingAsset);
  event HyperlaneRouteSet(uint32 indexed hplDomain, bytes1 indexed msgType, address indexed dest);

  uint256[] _chains;

  bytes32 public constant WRITER_ROLE = keccak256('WRITER_ROLE');

  constructor(address storageAddress) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _storage = Storage(storageAddress);
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
    return _chains;
  }

  function getChainName(uint256 chain) public view returns (string memory) {
    return _getString(_getChainNameKey(chain));
  }

  function getHyperlaneDomain(uint256 chain) public view returns (uint32) {
    return uint32(_getUint(_getHyperlaneDomainKey(chain)));
  }

  function getVault(uint256 chain, address asset) public view returns (address) {
    return _getAddress(_getVaultKey(chain, asset));
  }

  function getVaultUnderlyingAsset(uint256 chain, address vault) public view returns (address) {
    return _getAddress(_getVaultUnderlyingAssetKey(chain, vault));
  }

  function getChainByHyperlaneDomain(uint32 hplDomain) public view returns (uint256) {
    return _getUint(_getChainByHyperlaneDomainKey(hplDomain));
  }

  function getHyperlaneRoute(uint32 hplDomain, MsgType msgType) public view returns (address) {
    return _getAddress(_getHyperlaneRouteKey(hplDomain, msgType));
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

  function setChain(uint256 chain, string calldata name, uint32 hplDomain) public onlyWriter {
    if (_checkChainAlreadyRegistered(chain)) {
      revert Error.AlreadyRegistered();
    }
    _chains.push(chain);
    _setString(_getChainNameKey(chain), name);
    _setUint(_getHyperlaneDomainKey(chain), hplDomain);
    _setUint(_getChainByHyperlaneDomainKey(hplDomain), chain);
    emit ChainSet(chain, hplDomain, name);
  }

  function setVault(uint256 chain, address vault, address underlyingAsset) public onlyWriter onlyRegisteredChain(chain) {
    _setAddress(_getVaultKey(chain, underlyingAsset), vault);
    _setAddress(_getVaultUnderlyingAssetKey(chain, vault), underlyingAsset);
    emit VaultSet(chain, vault, underlyingAsset);
  }

  function setHyperlaneRoute(uint32 hplDomain, MsgType msgType, address dest) external onlyWriter {
    uint256 chain = getChainByHyperlaneDomain(hplDomain);
    if (chain == 0) revert Error.NotRegistered();
    _setAddress(_getHyperlaneRouteKey(hplDomain, msgType), dest);
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
    uint256[] memory chains = _chains;
    for (uint256 i = 0; i < chains.length; i++) {
      if (chain == chains[i]) {
        return true;
      }
    }
    return false;
  }
}
