// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from './core/IAssetManager.sol';
import { IDelegationRegistry } from './core/IDelegationRegistry.sol';
import { IOptOutQueue } from './core/IOptOutQueue.sol';
import { IEOLGaugeGovernor } from './governance/IEOLGaugeGovernor.sol';
import { IEOLProtocolGovernor } from './governance/IEOLProtocolGovernor.sol';

/**
 * @title IMitosis
 * @notice Interface for the main entry point of Mitosis contracts for third-party integrations.
 */
interface IMitosis {
  //====================== NOTE: CONTRACTS ======================//

  function optOutQueue() external view returns (IOptOutQueue optOutQueue_);
  function assetManager() external view returns (IAssetManager assetManager_);
  function delegationRegistry() external view returns (IDelegationRegistry delegationRegistry_);
  function eolGaugeGovernor(address eolVault) external view returns (IEOLGaugeGovernor eolGaugeGovernor_);
  function eolProtocolGovernor(address eolVault) external view returns (IEOLProtocolGovernor eolProtocolGovernor_);

  //====================== NOTE: DELEGATION ======================//

  function delegationManager(address account) external view returns (address delegationManager_);
  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);
  function redistributionRule(address account) external view returns (address redistributionRule_);

  function setDelegationManager(address account, address delegationManager_) external;
  function setDefaultDelegatee(address account, address defaultDelegatee_) external;
  function setRedistributionRule(address account, address redistributionRule_) external;
}
