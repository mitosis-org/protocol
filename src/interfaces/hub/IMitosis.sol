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

  /**
   * @notice Returns the address of the OptOutQueue contract.
   * @return optOutQueue_ The address of the OptOutQueue contract.
   */
  function optOutQueue() external view returns (IOptOutQueue optOutQueue_);

  /**
   * @notice Returns the address of the AssetManager contract.
   * @return assetManager_ The address of the AssetManager contract.
   */
  function assetManager() external view returns (IAssetManager assetManager_);

  /**
   * @notice Returns the address of the DelegationRegistry contract.
   * @return delegationRegistry_ The address of the DelegationRegistry contract.
   */
  function delegationRegistry() external view returns (IDelegationRegistry delegationRegistry_);

  /**
   * @notice Returns the address of the EOLProtocolGovernor contract.
   * @return eolProtocolGovernor_ The address of the EOLProtocolGovernor contract.
   */
  function eolProtocolGovernor() external view returns (IEOLProtocolGovernor eolProtocolGovernor_);

  /**
   * @notice Returns the address of the EOLGaugeGovernor contract.
   * @return eolGaugeGovernor_ The address of the EOLGaugeGovernor contract.
   */
  function eolGaugeGovernor() external view returns (IEOLGaugeGovernor eolGaugeGovernor_);

  //====================== NOTE: DELEGATION ======================//

  /**
   * @notice Returns the address of the delegation manager for the specified account.
   * @param account The account address
   * @return delegationManager_ The address of the delegation manager.
   */
  function delegationManager(address account) external view returns (address delegationManager_);

  /**
   * @notice Returns the address of the default delegatee for the specified account.
   * @param account The account address
   * @return defaultDelegatee_ The address of the default delegatee.
   */
  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);

  /**
   * @notice Sets the delegation manager for the specified account.
   * @param account The account address
   * @param delegationManager_ The address of the delegation manager.
   */
  function setDelegationManager(address account, address delegationManager_) external;

  /**
   * @notice Sets the default delegatee for the specified account.
   * @param account The account address
   * @param defaultDelegatee_ The address of the default delegatee.
   */
  function setDefaultDelegatee(address account, address defaultDelegatee_) external;
}
