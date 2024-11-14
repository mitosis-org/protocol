// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { EnumerableMap } from '@oz-v5/utils/structs/EnumerableMap.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';

import { IRewardRedistributor } from '../../interfaces/hub/reward/IRewardRedistributor.sol';
import { IMerkleRewardDistributor } from '../../interfaces/hub/reward/IMerkleRewardDistributor.sol';
import { ITWABRewardDistributor } from '../../interfaces/hub/reward/ITWABRewardDistributor.sol';
import { StdError } from '../../lib/StdError.sol';

contract RewardRedistributor is IRewardRedistributor, AccessControlEnumerableUpgradeable {
  using ERC7201Utils for string;

  bytes32 public constant MANAGER_ROLE = keccak256('MANAGER_ROLE');

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  struct RewardRedistributorStorage {
    ITWABRewardDistributor twabRewardDistributor;
    IMerkleRewardDistributor merkleRewardDistributor;
    uint256 currentId;
    mapping(uint256 id => Redistribution) redistributions;
  }

  string private constant _NAMESPACE = 'mitosis.storage.RewardRedistributorStorage';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getRewardRedistributorStorage() internal view returns (RewardRedistributorStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // =========== NOTE: INITIALIZATION FUNCTIONS =========== //

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address admin,
    ITWABRewardDistributor twabRewardDistributor,
    IMerkleRewardDistributor merkleRewardDistributor
  ) public initializer {
    __AccessControlEnumerable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    $.twabRewardDistributor = twabRewardDistributor;
    $.merkleRewardDistributor = merkleRewardDistributor;

    _moveToNextRedistribution($);
  }

  // ============================ NOTE: VIEW FUNCTIONS ============================ //

  function currentId() external view returns (uint256) {
    return _getRewardRedistributorStorage().currentId;
  }

  function redistribution(uint256 id) external view returns (Redistribution memory redist) {
    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    redist = $.redistributions[id];

    require(redist.id != 0, IRewardRedistributor__RedistributionNotFound(id));

    return redist;
  }

  // ============================ NOTE: MANAGER FUNCTIONS ============================ //

  function fetchRewards(
    uint256 id,
    uint256 nonce,
    address account,
    address eolVault,
    address reward,
    uint48 toTimestamp
  ) external onlyRole(MANAGER_ROLE) {
    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    Redistribution storage redist = $.redistributions[id];

    require(id == $.currentId, IRewardRedistributor__NotCurrentRedistributionId(id));
    require(nonce == redist.nonce, IRewardRedistributor__RedistributionInvalidNonce(id, nonce));

    _fetchRewards($, redist, account, eolVault, reward, toTimestamp);
  }

  function fetchRewardsMultiple(
    uint256 id,
    uint256 nonce,
    address account,
    address eolVault,
    address[] calldata rewards,
    uint48 toTimestamp
  ) external onlyRole(MANAGER_ROLE) {
    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    Redistribution storage redist = $.redistributions[id];

    require(id == $.currentId, IRewardRedistributor__NotCurrentRedistributionId(id));
    require(nonce == redist.nonce, IRewardRedistributor__RedistributionInvalidNonce(id, nonce));

    for (uint256 i = 0; i < rewards.length; i++) {
      _fetchRewards($, redist, account, eolVault, rewards[i], toTimestamp);
    }
  }

  function fetchRewardsBatch(
    uint256 id,
    uint256 nonce,
    address account,
    address[] calldata eolVaults,
    address[][] calldata rewards,
    uint48 toTimestamp
  ) external onlyRole(MANAGER_ROLE) {
    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    Redistribution storage redist = $.redistributions[id];

    require(id == $.currentId, IRewardRedistributor__NotCurrentRedistributionId(id));
    require(nonce == redist.nonce, IRewardRedistributor__RedistributionInvalidNonce(id, nonce));
    require(eolVaults.length == rewards.length, StdError.InvalidParameter('rewards.length'));

    for (uint256 i = 0; i < eolVaults.length; i++) {
      for (uint256 j = 0; j < rewards[i].length; j++) {
        _fetchRewards($, redist, account, eolVaults[i], rewards[i][j], toTimestamp);
      }
    }
  }

  function executeRedistribution(
    uint256 id,
    uint256 nonce,
    bytes32 merkleRoot,
    address[] calldata rewards,
    uint256[] calldata amounts
  ) external onlyRole(MANAGER_ROLE) returns (uint256 merkleStage) {
    RewardRedistributorStorage storage $ = _getRewardRedistributorStorage();
    Redistribution storage redist = $.redistributions[id];

    require(id == $.currentId, IRewardRedistributor__NotCurrentRedistributionId(id));
    require(nonce == redist.nonce, IRewardRedistributor__RedistributionInvalidNonce(id, nonce));
    require(rewards.length == amounts.length, StdError.InvalidParameter('amounts.length'));

    for (uint256 i = 0; i < rewards.length; i++) {
      IERC20(rewards[i]).transfer(address($.merkleRewardDistributor), amounts[i]);
    }

    merkleStage = $.merkleRewardDistributor.addStage(merkleRoot);

    redist.merkleStage = merkleStage;
    redist.merkleRoot = merkleRoot;
    redist.rewards = rewards;
    redist.amounts = amounts;

    emit RedistributionExecuted(id, merkleStage, merkleRoot, rewards, amounts);

    _moveToNextRedistribution($);

    return merkleStage;
  }

  // ============================ NOTE: INTERNAL FUNCTIONS ============================ //

  function _moveToNextRedistribution(RewardRedistributorStorage storage $) internal {
    $.currentId++;
    $.redistributions[$.currentId].id = $.currentId;
    emit RedistributionCreated($.currentId);
  }

  function _fetchRewards(
    RewardRedistributorStorage storage $,
    Redistribution storage redist,
    address account,
    address eolVault,
    address reward,
    uint48 toTimestamp
  ) internal {
    uint256 claimedAmount = $.twabRewardDistributor.claimForRedistribution(account, eolVault, reward, toTimestamp);
    emit RewardsFetched(redist.id, redist.nonce, account, eolVault, reward, claimedAmount, toTimestamp);
    redist.nonce++;
  }
}
