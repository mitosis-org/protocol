// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Script } from '@std/Script.sol';
import { Vm } from '@std/Vm.sol';

import { LibString } from '@solady/utils/LibString.sol';

/// @notice A example script to fetch multichain balances for the caller.
/// @dev The caller can be set via using the flag like `account` or `private-key` or `mnemonic` etc...
contract Multichain is Script {
  using LibString for string;

  function run() public {
    Vm.Rpc[] memory rpcs = vm.rpcUrlStructs();

    vm.startBroadcast();
    (, address caller,) = vm.readCallers();
    vm.stopBroadcast();

    for (uint256 i = 0; i < rpcs.length; i++) {
      if (rpcs[i].url.eq('')) {
        console.log('rpc url is empty. skipping. (key: %s)', rpcs[i].key);
        continue;
      }

      vm.createSelectFork(rpcs[i].key);
      uint256 balance = caller.balance;

      console.log('caller balance for network %s: %d', rpcs[i].key, balance);
    }
  }
}
