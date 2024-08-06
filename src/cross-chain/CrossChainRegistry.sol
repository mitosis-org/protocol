// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { ICrossChainRegistry } from '../interfaces/cross-chain/ICrossChainRegistry.sol';
import { MsgType } from './messages/Message.sol';

contract CrossChainRegistryStorageV1 {
  struct StorageV1 {
    uint256[] chains;
  }

  // keccak256(abi.encode(uint256(keccak256("mitosis.storage.CrossChainRegistryStorage.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0x6acd94fd2c3942266402dfa199ad817aa94ac6cd3de826b0b51cbc305ff61c00;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }

  // TODO(ray)
  function _getString(bytes32 key) internal view returns (string memory result) {
    assembly {
      let length := sload(key)
      result := mload(0x40)
      mstore(result, length)
      let content := sload(add(key, 1))
      mstore(add(result, 0x20), content)
      mstore(0x40, add(result, add(0x20, length)))
    }
  }

  function _getUint32(bytes32 key) internal view returns (uint32 result) {
    assembly {
      result := sload(key)
    }
  }

  function _getAddress(bytes32 key) internal view returns (address result) {
    assembly {
      result := sload(key)
    }
  }

  function _getUint256(bytes32 key) internal view returns (uint256 result) {
    assembly {
      result := sload(key)
    }
  }

  // TODO(ray)
  function _setString(bytes32 key, string memory value) internal {
    assembly {
      let length := mload(value)
      sstore(key, length)
      sstore(add(key, 1), value)
    }
  }

  function _setUint32(bytes32 key, uint32 value) internal {
    assembly {
      sstore(key, value)
    }
  }

  function _setAddress(bytes32 key, address value) internal {
    assembly {
      sstore(key, value)
    }
  }

  function _setUint256(bytes32 key, uint256 value) internal {
    assembly {
      sstore(key, value)
    }
  }
}

contract CrossChainRegistry is
  ICrossChainRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  CrossChainRegistryStorageV1
{
  bytes32 public constant REGISTERER_ROLE = keccak256('REGISTERER_ROLE');

  event ChainSet(uint256 indexed chain, uint32 indexed hplDomain, string name);
  event VaultSet(uint256 indexed chain, address indexed vault, address indexed underlyingAsset);
  event HyperlaneRouteSet(uint32 indexed hplDomain, bytes1 indexed msgType, address indexed dst);

  error CrossChainRegistry__NotRegistered();
  error CrossChainRegistry__AlreadyRegistered();

  modifier onlyRegisterer() {
    _checkRole(REGISTERER_ROLE);
    _;
  }

  modifier onlyRegisteredChain(uint256 chain) {
    if (!_checkChainAlreadyRegistered(chain)) {
      revert CrossChainRegistry__NotRegistered();
    }
    _;
  }

  //===========

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);
    _grantRole(DEFAULT_ADMIN_ROLE, owner);
  }

  // View functions

  function getChains() external view returns (uint256[] memory) {
    return _getStorageV1().chains;
  }

  function getChainName(uint256 chain) external view returns (string memory) {
    bytes32 key = _getChainNameKey(chain);
    return _getString(key);
  }

  function getHyperlaneDomain(uint256 chain) external view returns (uint32) {
    bytes32 key = _getHyperlaneDomainKey(chain);
    return _getUint32(key);
  }

  function getVault(uint256 chain, address asset) external view returns (address) {
    bytes32 key = _getVaultKey(chain, asset);
    return _getAddress(key);
  }

  function getVaultUnderlyingAsset(uint256 chain, address vault) external view returns (address) {
    bytes32 key = _getVaultUnderlyingAssetKey(chain, vault);
    return _getAddress(key);
  }

  function getChainByHyperlaneDomain(uint32 hplDomain) external view returns (uint256) {
    bytes32 key = _getChainByHyperlaneDomainKey(hplDomain);
    return _getUint256(key);
  }

  // Mutative functions
  //
  // TODO: update methods

  function setChain(uint256 chain, string calldata name, uint32 hplDomain) external onlyRegisterer {
    if (_checkChainAlreadyRegistered(chain)) {
      revert CrossChainRegistry__AlreadyRegistered();
    }
    StorageV1 storage $ = _getStorageV1();
    $.chains.push(chain);
    _setString(_getChainNameKey(chain), name);
    _setUint32(_getHyperlaneDomainKey(chain), hplDomain);
    _setUint256(_getChainByHyperlaneDomainKey(hplDomain), chain);
    emit ChainSet(chain, hplDomain, name);
  }

  function setVault(uint256 chain, address vault, address underlyingAsset)
    external
    onlyRegisterer
    onlyRegisteredChain(chain)
  {
    _setAddress(_getVaultKey(chain, underlyingAsset), vault);
    _setAddress(_getVaultUnderlyingAssetKey(chain, vault), underlyingAsset);
    emit VaultSet(chain, vault, underlyingAsset);
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
