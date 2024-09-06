// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ITWABSnapshots } from '../interfaces/twab/ITWABSnapshots.sol';

library TWABSnapshotsUtils {
  function getAccountTWABByTimestampRange(ITWABSnapshots snapshots, address account, uint48 startsAt, uint48 endsAt)
    public
    view
    returns (uint256)
  {
    (uint208 balanceA, uint256 twabA, uint48 positionA) = snapshots.getPastSnapshot(account, startsAt);
    (uint208 balanceB, uint256 twabB, uint48 positionB) = snapshots.getPastSnapshot(account, endsAt);

    twabA = _calculateTWAB(balanceA, twabA, positionA, startsAt);
    twabB = _calculateTWAB(balanceB, twabB, positionB, endsAt);

    return twabB - twabA;
  }

  function getTotalTWABByTimestampRange(ITWABSnapshots snapshots, uint48 startsAt, uint48 endsAt)
    public
    view
    returns (uint256)
  {
    (uint208 balanceA, uint256 twabA, uint48 positionA) = snapshots.getPastTotalSnapshot(startsAt);
    (uint208 balanceB, uint256 twabB, uint48 positionB) = snapshots.getPastTotalSnapshot(endsAt);

    twabA = _calculateTWAB(balanceA, twabA, positionA, startsAt);
    twabB = _calculateTWAB(balanceB, twabB, positionB, endsAt);

    return twabB - twabA;
  }

  /*
     balance
              start                   end                  
        │       │                      │                   
        │       │                      │                   
        │       │                      │   ┌──────────     
        │       │                      │   │               
        │       │               ┌──────┼───┘               
        │       │               │      │                   
        │       │       ┌───────┘      │                   
        │       │       │              │                   
        │       │       │              │                   
        │       │       │              │                   
        │       │  ┌────┘              │                   
        │    ┌──┼──┘                   │                   
        │    │  │                      │                   
        │    │  │                      │                   
        └────*──┼──*────*───────*──────┼──*─────────      block timestamp
            100 │ 150  180     250     │ 400               
             │  │               │      │                   
             ├──┤               ├──────┤                   
             │  │               │      │   
             A                  B                          
    */
  function _calculateTWAB(uint208 balance, uint256 twab, uint48 position, uint48 timestamp)
    private
    pure
    returns (uint256)
  {
    if (position < timestamp) {
      uint256 diff = timestamp - position;
      twab += balance * diff;
    }
    return twab;
  }
}
