// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Time } from '@oz-v5/utils/types/Time.sol';
import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';
import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { EOLProtocolRegistryStorageV1, ProtocolInfo } from './storage/EOLProtocolRegistryStorageV1.sol';
import { StdError } from '../../lib/StdError.sol';

contract EOLProtocolRegistry is Ownable2StepUpgradeable, AccessControlUpgradeable, EOLProtocolRegistryStorageV1 {
  using EnumerableSet for EnumerableSet.UintSet;

  event ProtocolRegistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name, string metadata
  );
  event ProtocolUnregistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name
  );

  event Authorized(address indexed eolAsset, address indexed account);
  event Unauthorized(address indexed eolAsset, address indexed account);

  error EOLProtocolRegistry_AlreadyRegistered(uint256 protocolId, address eolAsset, uint256 chainId, string name);
  error EOLProtocolRegistry_NotRegistered(uint256 protocolId);

  //=========== NOTE: INITIALIZATION FUNCTIONS ===========//

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner);

    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, owner);
  }

  //=========== NOTE: VIEW FUNCTIONS ===========//

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

  //=========== NOTE: MUTATION FUNCTIONS ===========//

  function registerProtocol(address eolAsset, uint256 chainId, string memory name, string memory metadata) external {
    StorageV1 storage $ = _getStorageV1();
    uint256 id = _protocolId(eolAsset, chainId, name);

    _assertOnlyAuthorized($, eolAsset);
    if (bytes(name).length == 0) revert StdError.InvalidParameter('name');
    if ($.protocols[id].protocolId != 0) {
      revert EOLProtocolRegistry_AlreadyRegistered(id, eolAsset, chainId, name);
    }

    $.protocols[id] = ProtocolInfo({
      protocolId: id,
      eolAsset: eolAsset,
      chainId: chainId,
      name: name,
      metadata: metadata,
      registeredAt: Time.timestamp()
    });

    $.indexes[eolAsset][chainId].protocolIds.add(id);

    emit ProtocolRegistered(id, eolAsset, chainId, name, metadata);
  }

  function unregisterProtocol(uint256 protocolId_) external {
    StorageV1 storage $ = _getStorageV1();
    ProtocolInfo storage p = $.protocols[protocolId_];

    if (p.protocolId == 0) revert EOLProtocolRegistry_NotRegistered(protocolId_);

    _assertOnlyAuthorized($, p.eolAsset);

    p.protocolId = 0;
    $.indexes[p.eolAsset][p.chainId].protocolIds.remove(protocolId_);

    emit ProtocolUnregistered(protocolId_, p.eolAsset, p.chainId, p.name);
  }

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function authorize(address eolAsset, address account) external onlyOwner {
    _getStorageV1().isAuthorized[eolAsset][account] = true;
    emit Authorized(eolAsset, account);
  }

  function unauthorize(address eolAsset, address account) external onlyOwner {
    _getStorageV1().isAuthorized[eolAsset][account] = false;
    emit Unauthorized(eolAsset, account);
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _assertOnlyAuthorized(StorageV1 storage $, address eolAsset) internal view {
    if (!$.isAuthorized[eolAsset][_msgSender()]) revert StdError.Unauthorized();
  }

  function _protocolId(address eolAsset, uint256 chainId, string memory name) internal pure returns (uint256) {
    bytes32 nameHash = keccak256(bytes(name));
    return uint256(keccak256(abi.encode(eolAsset, chainId, nameHash)));
  }
}
