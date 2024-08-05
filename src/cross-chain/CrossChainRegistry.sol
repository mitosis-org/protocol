// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { RegistryBase } from './RegistryBase.sol';
import { Storage } from '../lib/Storage.sol';
import { MsgType } from './messages/Message.sol';

contract CrossChainRegistry is RegistryBase {
  constructor(address storageAddress) {
    _storage = Storage(storageAddress);
  }

  uint256[] _chains;

  modifier onlyRegisteredChain(uint256 chain) {
    if (!_checkChainAlreadyRegistered(chain)) {
      revert('not registered chain');
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

  function getHyperlaneRoute(uint256 chain, MsgType msgType) public view returns (address) {
    return _getAddress(_getHyperlaneRouteKey(chain, msgType));
  }

  function getVault(uint256 chain, address asset) public view returns (address) {
    return _getAddress(_getVaultKey(chain, asset));
  }

  function getVaultUnderlyingAsset(uint256 chain, address vault) public view returns (address) {
    return _getAddress(_getVaultUnderlyingAssetKey(chain, vault));
  }

  function getStrategyExecutor(address eolVault, uint256 executorId, uint256 chain) public view returns (address) {
    return _getAddress(_getStrategyExecutorKey(eolVault, executorId, chain));
  }

  function getChainByHyperlaneDomain(uint32 hplDomain) public view returns (uint256) {
    return _getUint(_getChainByHyperlaneDomainKey(hplDomain));
  }

  // Mutative functions

  // TODO: update?
  function setChain(uint256 chain, string calldata name, uint32 hplDomain) public {
    if (_checkChainAlreadyRegistered(chain)) {
      revert('already registered chain');
    }
    _chains.push(chain);
    _setString(_getChainNameKey(chain), name);
    _setUint(_getHyperlaneDomainKey(chain), hplDomain);
    _setUint(_getChainByHyperlaneDomainKey(hplDomain), chain);
  }

  function setVault(uint256 chain, address vault, address underlyingAsset) public onlyRegisteredChain(chain) {
    _setAddress(_getVaultKey(chain, underlyingAsset), vault);
    _setAddress(_getVaultUnderlyingAssetKey(chain, vault), underlyingAsset);
  }

  function setStrategyExecutor(address eolVault, uint256 executorId, uint256 chain, address executor)
    external
    onlyRegisteredChain(chain)
  {
    _setAddress(_getStrategyExecutorKey(eolVault, executorId, chain), executor);
  }

  function setHyperlaneRoute(uint256 chain, MsgType msgType, address target) external onlyRegisteredChain(chain) {
    _setAddress(_getHyperlaneRouteKey(chain, msgType), target);
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

  function _getHyperlaneRouteKey(uint256 chain, MsgType msgType) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('chain', chain, '.routes', '.hyperlane', msgType));
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
    return keccak256(abi.encodePacked('hyperlane_domain', hplDomain));
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
