// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20TWABSnapshots as IHubAsset } from '../twab/IERC20TWABSnapshots.sol';
import { IERC4626TWABSnapshots as IEOLVault } from '../twab/IERC4626TWABSnapshots.sol';
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
  function eolGaugeGovernor() external view returns (IEOLGaugeGovernor eolGaugeGovernor_);
  function eolProtocolGovernor() external view returns (IEOLProtocolGovernor eolProtocolGovernor_);

  //====================== NOTE: ASSET ======================//

  function redeem(uint256 chainId, IHubAsset hubAsset, uint256 amount) external;
  function redeem(uint256 chainId, IHubAsset hubAsset, address to, uint256 amount) external;

  //====================== NOTE: EOL ======================//

  function optOutPeriod(IEOLVault eolVault) external view returns (uint256 optOutPeriod_);

  function optOutRequestInfo(IEOLVault eolVault, uint256 requestId)
    external
    view
    returns (IOptOutQueue.GetRequestResponse memory resp);

  function optOutStatus(IEOLVault eolVault, uint256 requestId)
    external
    view
    returns (IOptOutQueue.RequestStatus optOutStatus_);

  function optIn(IEOLVault eolVault, uint256 amount) external;
  function optIn(IEOLVault eolVault, address assetOwner, uint256 amount) external;
  function optIn(IEOLVault eolVault, address assetOwner, address receiver, uint256 amount) external;

  function optOutRequest(IEOLVault eolVault, uint256 amount) external returns (uint256 requestId);
  function optOutRequest(IEOLVault eolVault, address assetOwner, uint256 amount) external returns (uint256 requestId);
  function optOutRequest(IEOLVault eolVault, address assetOwner, address receiver, uint256 amount)
    external
    returns (uint256 requestId);

  function optOutClaim(IEOLVault eolVault) external;
  function optOutClaim(IEOLVault eolVault, address receiver) external;

  //====================== NOTE: DELEGATION ======================//

  function delegationManager(address account) external view returns (address delegationManager_);
  function defaultDelegatee(address account) external view returns (address defaultDelegatee_);
  function redistributionRule(address account) external view returns (address redistributionRule_);

  function setDelegationManager(address account, address delegationManager_) external;
  function setDefaultDelegatee(address account, address defaultDelegatee_) external;
  function setRedistributionRule(address account, address redistributionRule_) external;
}
