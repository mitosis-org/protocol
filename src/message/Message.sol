// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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

// hub -> branch
struct MsgInitializeAsset {
  bytes32 asset;
}

// branch -> hub
struct MsgDeposit {
  bytes32 asset;
  bytes32 to;
  uint256 amount;
}

// hub -> branch
struct MsgRedeem {
  bytes32 asset;
  bytes32 to;
  uint256 amount;
}

// hub -> branch
struct MsgInitializeEOL {
  uint256 eolId;
  bytes32 asset;
}

// hub -> branch
struct MsgAllocateEOL {
  uint256 eolId;
  uint256 amount;
}

// branch -> hub
struct MsgDeallocateEOL {
  uint256 eolId;
  uint256 amount;
}

// branch -> hub
struct MsgSettleYield {
  uint256 eolId;
  uint256 amount;
}

// branch -> hub
struct MsgSettleLoss {
  uint256 eolId;
  uint256 amount;
}

// branch -> hub
struct MsgSettleExtraRewards {
  uint256 eolId;
  bytes32 reward;
  uint256 amount;
}

library Message {
  error Message__InvalidMsgType(MsgType actual, MsgType expected);
  error Message__InvalidMsgLength(uint256 actual, uint256 expected);

  uint256 public constant LEN_MSG_INITIALIZE_ASSET = 33;
  uint256 public constant LEN_MSG_DEPOSIT = 97;
  uint256 public constant LEN_MSG_REDEEM = 97;
  uint256 public constant LEN_MSG_INITIALIZE_EOL = 65;
  uint256 public constant LEN_MSG_ALLOCATE_EOL = 65;
  uint256 public constant LEN_MSG_DEALLOCATE_EOL = 65;
  uint256 public constant LEN_MSG_SETTLE_YIELD = 65;
  uint256 public constant LEN_MSG_SETTLE_LOSS = 65;
  uint256 public constant LEN_MSG_SETTLE_EXTRA_REWARDS = 97;

  function msgType(bytes calldata msg_) internal pure returns (MsgType) {
    return MsgType(uint8(msg_[0]));
  }

  function assertMsg(bytes calldata msg_, MsgType expectedType, uint256 expectedLen) internal pure {
    require(msgType(msg_) == expectedType, Message__InvalidMsgType(msgType(msg_), expectedType));
    require(msg_.length == expectedLen, Message__InvalidMsgLength(msg_.length, expectedLen));
  }

  function encode(MsgInitializeAsset memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgInitializeAsset), msg_.asset);
  }

  function decodeInitializeAsset(bytes calldata msg_) internal pure returns (MsgInitializeAsset memory decoded) {
    assertMsg(msg_, MsgType.MsgInitializeAsset, LEN_MSG_INITIALIZE_ASSET);

    decoded.asset = bytes32(msg_[1:]);
  }

  function encode(MsgDeposit memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgDeposit), msg_.asset, msg_.to, msg_.amount);
  }

  function decodeDeposit(bytes calldata msg_) internal pure returns (MsgDeposit memory decoded) {
    assertMsg(msg_, MsgType.MsgDeposit, LEN_MSG_DEPOSIT);

    decoded.asset = bytes32(msg_[1:33]);
    decoded.to = bytes32(msg_[33:65]);
    decoded.amount = uint256(bytes32(msg_[65:]));
  }

  function encode(MsgRedeem memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgRedeem), msg_.asset, msg_.to, msg_.amount);
  }

  function decodeRedeem(bytes calldata msg_) internal pure returns (MsgRedeem memory decoded) {
    assertMsg(msg_, MsgType.MsgRedeem, LEN_MSG_REDEEM);

    decoded.asset = bytes32(msg_[1:33]);
    decoded.to = bytes32(msg_[33:65]);
    decoded.amount = uint256(bytes32(msg_[65:]));
  }

  function encode(MsgInitializeEOL memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgInitializeEOL), msg_.eolId, msg_.asset);
  }

  function decodeInitializeEOL(bytes calldata msg_) internal pure returns (MsgInitializeEOL memory decoded) {
    assertMsg(msg_, MsgType.MsgInitializeEOL, LEN_MSG_INITIALIZE_EOL);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.asset = bytes32(msg_[33:]);
  }

  function encode(MsgAllocateEOL memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgAllocateEOL), msg_.eolId, msg_.amount);
  }

  function decodeAllocateEOL(bytes calldata msg_) internal pure returns (MsgAllocateEOL memory decoded) {
    assertMsg(msg_, MsgType.MsgAllocateEOL, LEN_MSG_ALLOCATE_EOL);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgDeallocateEOL memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgDeallocateEOL), msg_.eolId, msg_.amount);
  }

  function decodeDeallocateEOL(bytes calldata msg_) internal pure returns (MsgDeallocateEOL memory decoded) {
    assertMsg(msg_, MsgType.MsgDeallocateEOL, LEN_MSG_DEALLOCATE_EOL);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleYield memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleYield), msg_.eolId, msg_.amount);
  }

  function decodeSettleYield(bytes calldata msg_) internal pure returns (MsgSettleYield memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleYield, LEN_MSG_SETTLE_YIELD);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleLoss memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleLoss), msg_.eolId, msg_.amount);
  }

  function decodeSettleLoss(bytes calldata msg_) internal pure returns (MsgSettleLoss memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleLoss, LEN_MSG_SETTLE_LOSS);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleExtraRewards memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleExtraRewards), msg_.eolId, msg_.reward, msg_.amount);
  }

  function decodeSettleExtraRewards(bytes calldata msg_) internal pure returns (MsgSettleExtraRewards memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleExtraRewards, LEN_MSG_SETTLE_EXTRA_REWARDS);

    decoded.eolId = uint256(bytes32(msg_[1:33]));
    decoded.reward = bytes32(msg_[33:65]);
    decoded.amount = uint256(bytes32(msg_[65:]));
  }
}
