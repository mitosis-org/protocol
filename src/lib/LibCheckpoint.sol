// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { StdError } from './StdError.sol';

library LibCheckpoint {
  using SafeCast for uint256;

  struct TWABCheckpoint {
    uint256 twab;
    uint208 amount;
    uint48 lastUpdate;
  }

  struct TraceTWAB {
    TWABCheckpoint[] checkpoints;
  }

  function add(uint256 x, uint256 y) internal pure returns (uint256) {
    return x + y;
  }

  function sub(uint256 x, uint256 y) internal pure returns (uint256) {
    return x - y;
  }

  function len(TraceTWAB storage self) internal view returns (uint256) {
    return self.checkpoints.length;
  }

  function last(TraceTWAB storage self) internal view returns (TWABCheckpoint storage) {
    return self.checkpoints[len(self) - 1];
  }

  function push(
    TraceTWAB storage self,
    uint256 amount,
    uint48 now_,
    function (uint256, uint256) returns (uint256) nextAmountFunc
  ) internal {
    if (self.checkpoints.length == 0) {
      self.checkpoints.push(TWABCheckpoint({ twab: 0, amount: amount.toUint208(), lastUpdate: now_ }));
    } else {
      TWABCheckpoint memory last_ = last(self);
      self.checkpoints.push(
        TWABCheckpoint({
          twab: last_.amount * (now_ - last_.lastUpdate),
          amount: nextAmountFunc(last_.amount, amount).toUint208(),
          lastUpdate: now_
        })
      );
    }
  }

  function findAmount(TraceTWAB storage self, uint48 timestamp) internal view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    return len(self) == 0 ? 0 : lowerBound(self, timestamp).amount;
  }

  function findTWAB(TraceTWAB storage self, uint48 timestamp) internal view returns (uint256) {
    require(timestamp > 0, StdError.InvalidParameter('timestamp'));
    if (len(self) == 0) return 0;

    TWABCheckpoint memory checkpoint = lowerBound(self, timestamp);
    return checkpoint.twab + (checkpoint.amount * (timestamp - checkpoint.lastUpdate));
  }

  /// @notice Find the latest checkpoint with lastUpdate <= timestamp
  /// @dev Uses binary search to find the lower bound checkpoint
  function lowerBound(TraceTWAB storage self, uint48 timestamp) internal view returns (TWABCheckpoint memory) {
    TWABCheckpoint memory last_ = last(self);
    if (last_.lastUpdate <= timestamp) return last_;

    uint256 left = 0;
    uint256 right = self.checkpoints.length - 1;
    uint256 target = 0;

    while (left <= right) {
      uint256 mid = left + (right - left) / 2;
      if (self.checkpoints[mid].lastUpdate <= timestamp) {
        target = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return self.checkpoints[target];
  }

  /// @notice Find the earliest checkpoint with lastUpdate >= timestamp
  /// @dev Uses binary search to find the upper bound checkpoint
  function upperBound(TraceTWAB storage self, uint48 timestamp) internal view returns (TWABCheckpoint memory) {
    TWABCheckpoint memory first_ = self.checkpoints[0];
    if (first_.lastUpdate >= timestamp) return first_;

    uint256 left = 0;
    uint256 right = self.checkpoints.length - 1;
    uint256 target = right;

    while (left <= right) {
      uint256 mid = left + (right - left) / 2;
      if (self.checkpoints[mid].lastUpdate >= timestamp) {
        target = mid;
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return self.checkpoints[target];
  }
}
