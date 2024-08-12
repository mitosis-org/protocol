// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum MsgType {
  MsgDeposit,
  MsgRedeem,
  MsgAllocateEOL,
  MsgDeallocateEOL,
  MsgSettleYield,
  MsgSettleLoss,
  MsgSettleExtraRewards
}
