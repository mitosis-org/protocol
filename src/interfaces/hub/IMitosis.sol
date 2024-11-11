// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAssetManager } from './core/IAssetManager.sol';
import { IDelegationRegistry } from './core/IDelegationRegistry.sol';
import { IRedistributionRegistry } from './core/IRedistributionRegistry.sol';
import { IEOLGaugeGovernor } from './eol/governance/IEOLGaugeGovernor.sol';
import { IEOLProtocolGovernor } from './eol/governance/IEOLProtocolGovernor.sol';
import { IOptOutQueue } from './eol/IOptOutQueue.sol';

/**
 * @title IMitosis
 * @notice Interface for the main entry point of Mitosis contracts for third-party integrations.
 */
interface IMitosis {
  //====================== NOTE: CONTRACTS ======================//

  /**
   * @notice Returns the address of the OptOutQueue contract.
   */
  function optOutQueue() external view returns (IOptOutQueue);

  /**
   * @notice Returns the address of the AssetManager contract.
   */
  function assetManager() external view returns (IAssetManager);

  /**
   * @notice Returns the address of the DelegationRegistry contract.
   */
  function delegationRegistry() external view returns (IDelegationRegistry);

  /**
   * @notice Returns the address of the EOLProtocolGovernor contract.
   */
  function eolProtocolGovernor() external view returns (IEOLProtocolGovernor);

  /**
   * @notice Returns the address of the EOLGaugeGovernor contract.
   */
  function eolGaugeGovernor() external view returns (IEOLGaugeGovernor);

  /**
   * @notice Returns the address of the RedistributionRegistry contract.
   */
  function redistributionRegistry() external view returns (IRedistributionRegistry);

  //====================== NOTE: DELEGATION ======================//

  /**
   * @notice Returns the address of the delegation manager for the specified account.
   * @param account The account address
   */
  function delegationManager(address account) external view returns (address);

  /**
   * @notice Returns the address of the default delegatee for the specified account.
   * @param account The account address
   */
  function defaultDelegatee(address account) external view returns (address);

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

  //====================== NOTE: REDISTRIBUTION ======================//

  /**
   * @notice Returns if a redistribution is enabled for `account`
   * @param account The account address
   */
  function isRedistributionEnabled(address account) external view returns (bool);

  /**
   * @notice Enables redistribution for the `msg.sender`
   */
  function enableRedistribution() external;
}
