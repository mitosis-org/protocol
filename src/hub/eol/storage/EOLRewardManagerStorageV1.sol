// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
  DistributionType, IEOLRewardConfiguratorStorageV1
} from '../../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardManagerStorageV1 } from '../../../interfaces/hub/eol/IEOLRewardManager.sol';
import { IEOLRewardConfigurator } from '../../../interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../../interfaces/hub/eol/IEOLRewardDistributor.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';
import { StdError } from '../../../lib/StdError.sol';

contract EOLRewardManagerStorageV1 is IEOLRewardManagerStorageV1 {
  using ERC7201Utils for string;

  struct RewardInfo {
    address asset;
    uint256 amount;
    bool dispatched;
  }

  struct StorageV1 {
    address assetManager;
    IEOLRewardConfigurator rewardConfigurator;
    mapping(address eolVault => mapping(uint48 timestamp => RewardInfo[] rewardInfos)) rewardTreasury;
  }

  string private constant _NAMESPACE = 'mitosis.storage.EOLRewardManagerStorage.v1';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  //=========== NOTE: INTERNAL FUNCTIONS ===========//

  function _distributor(StorageV1 storage $, DistributionType distributionType)
    internal
    view
    returns (IEOLRewardDistributor distributor)
  {
    if (distributionType == DistributionType.TWAB) {
      distributor = $.rewardConfigurator.defaultDistributor(DistributionType.TWAB);
    } else if (distributionType == DistributionType.MerkleProof) {
      distributor = $.rewardConfigurator.defaultDistributor(DistributionType.MerkleProof);
    } else {
      revert StdError.NotImplemented();
    }
  }

  function _assertDistributorRegistered(StorageV1 storage $, IEOLRewardDistributor distributor) internal view {
    require(
      $.rewardConfigurator.isDistributorRegistered(distributor),
      IEOLRewardConfiguratorStorageV1.IEOLRewardConfiguratorStorageV1__RewardDistributorNotRegistered()
    );
  }
}
