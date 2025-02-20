// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AccessControlEnumerableUpgradeable } from '@ozu-v5/access/extensions/AccessControlEnumerableUpgradeable.sol';
import { TimelockControllerUpgradeable } from '@ozu-v5/governance/TimelockControllerUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';

import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract BranchTimelock is TimelockControllerUpgradeable, UUPSUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.BranchTimelock
  struct BranchTimelockStorage {
    uint256 operationIndex;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.BranchTimelock';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getBranchTimelockStorage() private view returns (BranchTimelockStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
    public
    override
    initializer
  {
    __UUPSUpgradeable_init();
    __TimelockController_init(minDelay, proposers, executors, admin);
  }

  // =========================== NOTE: MUTATIVE METHODS =========================== //

  function schedule(address, uint256, bytes calldata, bytes32, bytes32, uint256) public pure override {
    revert StdError.NotSupported();
  }

  function scheduleBatch(address[] calldata, uint256[] calldata, bytes[] calldata, bytes32, bytes32, uint256)
    public
    pure
    override
  {
    revert StdError.NotSupported();
  }

  function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, uint256 delay)
    public
    onlyRole(PROPOSER_ROLE)
  {
    BranchTimelockStorage storage $ = _getBranchTimelockStorage();
    super.schedule(target, value, data, predecessor, _salt($), delay);
    $.operationIndex++;
  }

  function scheduleBatch(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata payloads,
    bytes32 predecessor,
    uint256 delay
  ) public onlyRole(PROPOSER_ROLE) {
    BranchTimelockStorage storage $ = _getBranchTimelockStorage();
    super.scheduleBatch(targets, values, payloads, predecessor, _salt($), delay);
    $.operationIndex++;
  }

  // =========================== NOTE: INTERNAL METHODS =========================== //

  function _salt(BranchTimelockStorage storage $) internal view returns (bytes32) {
    return bytes32($.operationIndex);
  }

  function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
