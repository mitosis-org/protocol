// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { IAssetManager } from '../interfaces/hub/core/IAssetManager.sol';
import { IDelegationRegistry } from '../interfaces/hub/core/IDelegationRegistry.sol';
import { IOptOutQueue } from '../interfaces/hub/core/IOptOutQueue.sol';
import { IEOLGaugeGovernor } from '../interfaces/hub/governance/IEOLGaugeGovernor.sol';
import { IEOLProtocolGovernor } from '../interfaces/hub/governance/IEOLProtocolGovernor.sol';
import { IMitosis } from '../interfaces/hub/IMitosis.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';

/**
 * @title Mitosis
 * @notice Main entry point for Mitosis contracts for third-party integrations.
 */
contract Mitosis is IMitosis, Ownable2StepUpgradeable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.Mitosis
  struct MitosisStorage {
    IAssetManager assetManager;
    IOptOutQueue optOutQueue;
    IDelegationRegistry delegationRegistry;
    mapping(address eolVault => IEOLGaugeGovernor) eolGaugeGovernors;
    mapping(address eolVault => IEOLProtocolGovernor) eolProtocolGovernors;
  }

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.Mitosis';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getMitosisStorage() private view returns (MitosisStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // =========================== NOTE: INITIALIZERS  =========================== //

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_) external initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
  }

  // =========================== NOTE: IMitosis  =========================== //

  /**
   * @inheritdoc IMitosis
   */
  function optOutQueue() external view returns (IOptOutQueue optOutQueue_) {
    return _getMitosisStorage().optOutQueue;
  }

  /**
   * @inheritdoc IMitosis
   */
  function assetManager() external view returns (IAssetManager assetManager_) {
    return _getMitosisStorage().assetManager;
  }

  /**
   * @inheritdoc IMitosis
   */
  function delegationRegistry() external view returns (IDelegationRegistry delegationRegistry_) {
    return _getMitosisStorage().delegationRegistry;
  }

  /**
   * @inheritdoc IMitosis
   */
  function eolGaugeGovernor(address eolVault) external view returns (IEOLGaugeGovernor eolGaugeGovernor_) {
    return _getMitosisStorage().eolGaugeGovernors[eolVault];
  }

  /**
   * @inheritdoc IMitosis
   */
  function eolProtocolGovernor(address eolVault) external view returns (IEOLProtocolGovernor eolProtocolGovernor_) {
    return _getMitosisStorage().eolProtocolGovernors[eolVault];
  }

  /**
   * @inheritdoc IMitosis
   */
  function delegationManager(address account) external view returns (address delegationManager_) {
    return _getMitosisStorage().delegationRegistry.delegationManager(account);
  }

  /**
   * @inheritdoc IMitosis
   */
  function defaultDelegatee(address account) external view returns (address defaultDelegatee_) {
    return _getMitosisStorage().delegationRegistry.defaultDelegatee(account);
  }

  /**
   * @inheritdoc IMitosis
   */
  function setDelegationManager(address account, address delegationManager_) external {
    _getMitosisStorage().delegationRegistry.setDelegationManager(account, delegationManager_);
  }

  /**
   * @inheritdoc IMitosis
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external {
    _getMitosisStorage().delegationRegistry.setDefaultDelegatee(account, defaultDelegatee_);
  }

  // =========================== NOTE: State Setter  =========================== //

  function setAssetManager(IAssetManager assetManager_) external onlyOwner {
    MitosisStorage storage $ = _getMitosisStorage();
    $.assetManager = assetManager_;
    $.optOutQueue = IOptOutQueue(assetManager_.optOutQueue());
  }

  function setDelegationRegistry(IDelegationRegistry delegationRegistry_) external onlyOwner {
    _getMitosisStorage().delegationRegistry = delegationRegistry_;
  }

  function setEOLGaugeGovernor(address eolVault, IEOLGaugeGovernor eolGaugeGovernor_) external onlyOwner {
    _getMitosisStorage().eolGaugeGovernors[eolVault] = eolGaugeGovernor_;
  }

  function setEOLProtocolGovernor(address eolVault, IEOLProtocolGovernor eolProtocolGovernor_) external onlyOwner {
    _getMitosisStorage().eolProtocolGovernors[eolVault] = eolProtocolGovernor_;
  }
}
