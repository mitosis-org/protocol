// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ContextUpgradeable } from '@ozu-v5/utils/ContextUpgradeable.sol';

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IEOLProtocolRegistryStorageV1, ProtocolInfo } from '../../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { StdError } from '../../../lib/StdError.sol';

abstract contract EOLProtocolRegistryStorageV1 is IEOLProtocolRegistryStorageV1, ContextUpgradeable {
  using EnumerableSet for EnumerableSet.UintSet;
  using ERC7201Utils for string;

  event Authorized(address indexed eolAsset, address indexed account);
  event Unauthorized(address indexed eolAsset, address indexed account);

  struct IndexData {
    EnumerableSet.UintSet protocolIds;
  }

  struct StorageV1 {
    mapping(uint256 protocolId => ProtocolInfo) protocols;
    mapping(address eolAsset => mapping(uint256 chainId => IndexData)) indexes;
    mapping(address eolAsset => mapping(address account => bool)) isAuthorized;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLProtocolRegistryStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  function protocolIds(address eolAsset, uint256 chainId) external view returns (uint256[] memory) {
    return _getStorageV1().indexes[eolAsset][chainId].protocolIds.values();
  }

  function protocolId(address eolAsset, uint256 chainId, string memory name) external pure returns (uint256) {
    return _protocolId(eolAsset, chainId, name);
  }

  function protocol(uint256 protocolId_) public view returns (ProtocolInfo memory) {
    return _getStorageV1().protocols[protocolId_];
  }

  function isProtocolRegistered(uint256 protocolId_) external view returns (bool) {
    return protocol(protocolId_).protocolId != 0;
  }

  function isProtocolRegistered(address eolAsset, uint256 chainId, string memory name) external view returns (bool) {
    return protocol(_protocolId(eolAsset, chainId, name)).protocolId != 0;
  }

  function isAuthorized(address eolAsset, address account) external view returns (bool) {
    return _getStorageV1().isAuthorized[eolAsset][account];
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _authorize(address eolAsset, address account) internal {
    _getStorageV1().isAuthorized[eolAsset][account] = true;
    emit Authorized(eolAsset, account);
  }

  function _unauthorize(address eolAsset, address account) internal {
    _getStorageV1().isAuthorized[eolAsset][account] = false;
    emit Unauthorized(eolAsset, account);
  }

  function _assertOnlyAuthorized(StorageV1 storage $, address eolAsset) internal view {
    require($.isAuthorized[eolAsset][_msgSender()], StdError.Unauthorized());
  }

  function _protocolId(address eolAsset, uint256 chainId, string memory name) internal pure returns (uint256) {
    bytes32 nameHash = keccak256(bytes(name));
    return uint256(keccak256(abi.encode(eolAsset, chainId, nameHash)));
  }
}
