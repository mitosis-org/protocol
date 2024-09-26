// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';

import { IDelegationRegistry } from '../../interfaces/hub/core/IDelegationRegistry.sol';
import { IRedistributionRule } from '../../interfaces/hub/reward/IRedistributionRule.sol';

/**
 * @notice A redistribution rule that redistributes rewards based on the balances of an ERC20 token.
 * @dev This contract assumed that the source account is ERC20 token.
 */
contract ERC20Redistributor is IRedistributionRule {
  IDelegationRegistry internal immutable _delegationRegistry;

  constructor(address delegationRegistry_) {
    _delegationRegistry = IDelegationRegistry(delegationRegistry_);
  }

  function delegationRegistry() external view returns (IDelegationRegistry delegationRegistry_) {
    return _delegationRegistry;
  }

  function getTotalWeight(address source_) external view override returns (uint256 totalWeight) {
    return _validateSource(source_).totalSupply();
  }

  function getTotalWeight(address[] memory sources_) external view override returns (uint256[] memory totalWeights) {
    totalWeights = new uint256[](sources_.length);
    for (uint256 i; i < sources_.length; i++) {
      totalWeights[i] = _validateSource(sources_[i]).totalSupply();
    }
    return totalWeights;
  }

  function getWeight(address source_, address account) external view override returns (uint256 weight) {
    return _validateSource(source_).balanceOf(account);
  }

  function getWeight(address source_, address[] memory accounts)
    external
    view
    override
    returns (uint256[] memory weights)
  {
    weights = new uint256[](accounts.length);
    for (uint256 i; i < accounts.length; i++) {
      weights[i] = _validateSource(source_).balanceOf(accounts[i]);
    }
    return weights;
  }

  function _validateSource(address source) private view returns (IERC20) {
    require(source.code.length > 0, IRedistributionRule__SourceIsNotContract(source));

    address rule = _delegationRegistry.redistributionRule(source);
    require(rule == address(this), IRedistributionRule__SourceIsNotRegistered(source));

    return IERC20(source);
  }
}
