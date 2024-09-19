// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';
import { ERC20TWABSnapshots } from './ERC20TWABSnapshots.sol';

contract TokenRegistry {
  using EnumerableSet for EnumerableSet.AddressSet;

  event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

  EnumerableSet.AddressSet private _tokens;
  mapping(address => address) private _delegates;

  function register(address token) external {
    _tokens.add(token);
  }

  function delegates(address account) public view returns (address) {
    address delegatee = _delegates[account];
    return delegatee == address(0) ? account : delegatee;
  }

  function delegate(address delegatee) public {
    _delegate(msg.sender, delegatee);
  }

  function _delegate(address delegator, address delegatee) internal {
    address currentDelegate = delegates(delegator);
    _delegates[delegator] = delegatee;

    emit DelegateChanged(delegator, currentDelegate, delegatee);

    // move voting power for all tokens.
    for (uint256 i = 0; i < _tokens.length(); i++) {
      ERC20TWABSnapshots token = ERC20TWABSnapshots(_tokens.at(i));
      uint256 delegatorBalance = token.balanceOf(delegator);
      token.moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }
  }
}
