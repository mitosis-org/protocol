// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { IEOLProtocolRegistry } from '../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { StdError } from '../../lib/StdError.sol';
import { EOLProtocolRegistryStorageV1, ProtocolInfo } from './EOLProtocolRegistryStorageV1.sol';

contract EOLProtocolRegistry is
  IEOLProtocolRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  EOLProtocolRegistryStorageV1
{
  using EnumerableSet for EnumerableSet.UintSet;

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
    require(bytes(name).length > 0, StdError.InvalidParameter('name'));
    require($.protocols[id].protocolId == 0, IEOLProtocolRegistry__AlreadyRegistered(id, eolAsset, chainId, name));

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

    require(p.protocolId != 0, IEOLProtocolRegistry__NotRegistered(protocolId_));
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
    require($.isAuthorized[eolAsset][_msgSender()], StdError.Unauthorized());
  }

  function _protocolId(address eolAsset, uint256 chainId, string memory name) internal pure returns (uint256) {
    bytes32 nameHash = keccak256(bytes(name));
    return uint256(keccak256(abi.encode(eolAsset, chainId, nameHash)));
  }
}
