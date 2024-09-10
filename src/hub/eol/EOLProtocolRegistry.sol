// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { AccessControlUpgradeable } from '@ozu-v5/access/AccessControlUpgradeable.sol';
import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';

import { IEOLProtocolRegistry } from '../../interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { StdError } from '../../lib/StdError.sol';
import { EOLProtocolRegistryStorageV1, ProtocolInfo } from './storage/EOLProtocolRegistryStorageV1.sol';

contract EOLProtocolRegistry is
  IEOLProtocolRegistry,
  Ownable2StepUpgradeable,
  AccessControlUpgradeable,
  EOLProtocolRegistryStorageV1
{
  using EnumerableSet for EnumerableSet.UintSet;

  event ProtocolRegistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name, string metadata
  );
  event ProtocolUnregistered(
    uint256 indexed protocolId, address indexed eolAsset, uint256 indexed chainId, string name
  );

  error EOLProtocolRegistry__AlreadyRegistered(uint256 protocolId, address eolAsset, uint256 chainId, string name);
  error EOLProtocolRegistry__NotRegistered(uint256 protocolId);

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

  //=========== NOTE: MUTATION FUNCTIONS ===========//

  function registerProtocol(address eolAsset, uint256 chainId, string memory name, string memory metadata) external {
    StorageV1 storage $ = _getStorageV1();
    uint256 id = _protocolId(eolAsset, chainId, name);

    _assertOnlyAuthorized($, eolAsset);
    require(bytes(name).length > 0, StdError.InvalidParameter('name'));
    require($.protocols[id].protocolId == 0, EOLProtocolRegistry__AlreadyRegistered(id, eolAsset, chainId, name));

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

    require(p.protocolId != 0, EOLProtocolRegistry__NotRegistered(protocolId_));
    _assertOnlyAuthorized($, p.eolAsset);

    p.protocolId = 0;
    $.indexes[p.eolAsset][p.chainId].protocolIds.remove(protocolId_);

    emit ProtocolUnregistered(protocolId_, p.eolAsset, p.chainId, p.name);
  }

  function authorize(address eolAsset, address account) external onlyOwner {
    _authorize(eolAsset, account);
  }

  function unauthorize(address eolAsset, address account) external onlyOwner {
    _unauthorize(eolAsset, account);
  }
}
