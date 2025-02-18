// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';
import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

contract ValidatorRewardFeedStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    bytes placeholder;
  }

  string private constant _NAMESPACE = 'mitosis.storage.ValidatorRewardFeedStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}

contract ValidatorRewardFeed is
  ValidatorRewardFeedStorageV1,
  Ownable2StepUpgradeable,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable
{
  /// @notice keccak256('mitosis.role.ValidatorRewardFeed.feeder')
  bytes32 public constant FEEDER_ROLE = 0xed3cedcdadd7625ff13ce12c112792caf5f35e0f515e9d8bd5cb9ad0c4cd4262;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    require(owner_ != address(0), StdError.ZeroAddress('owner'));

    __Ownable_init(owner_);
    __Ownable2Step_init();
    __AccessControl_init();
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, owner_);
  }

  // ================== UUPS ================== //

  function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
    require(newImplementation != address(0), StdError.ZeroAddress('newImpl'));
  }
}
