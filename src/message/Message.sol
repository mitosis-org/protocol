// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum MsgType {
  //=========== NOTE: Asset ===========//
  MsgInitializeAsset,
  MsgDeposit,
  MsgRedeem,
  //=========== NOTE: EOL ===========//
  MsgInitializeEOL,
  MsgAllocateEOL,
  MsgDeallocateEOL,
  MsgSettleYield,
  MsgSettleLoss,
  MsgSettleExtraRewards
}
