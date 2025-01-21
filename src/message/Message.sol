// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

enum MsgType {
  //=========== NOTE: Asset ===========//
  MsgInitializeAsset,
  MsgDeposit,
  MsgDepositWithMatrixSupply,
  MsgRedeem,
  //=========== NOTE: Matrix ===========//
  MsgInitializeMatrix,
  MsgAllocateMatrixLiquidity,
  MsgDeallocateMatrixLiquidity,
  MsgSettleMatrixYield,
  MsgSettleMatrixLoss,
  MsgSettleMatrixExtraRewards
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

// branch -> hub
struct MsgDepositWithMatrixSupply {
  bytes32 asset;
  bytes32 to;
  bytes32 matrixBasketAsset;
  uint256 amount;
}

// hub -> branch
struct MsgRedeem {
  bytes32 asset;
  bytes32 to;
  uint256 amount;
}

// hub -> branch
struct MsgInitializeMatrix {
  bytes32 matrixBasketAsset;
  bytes32 asset;
}

// hub -> branch
struct MsgAllocateMatrixLiquidity {
  bytes32 matrixBasketAsset;
  uint256 amount;
}

// branch -> hub
struct MsgDeallocateMatrixLiquidity {
  bytes32 matrixBasketAsset;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixYield {
  bytes32 matrixBasketAsset;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixLoss {
  bytes32 matrixBasketAsset;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixExtraRewards {
  bytes32 matrixBasketAsset;
  bytes32 reward;
  uint256 amount;
}

library Message {
  error Message__InvalidMsgType(MsgType actual, MsgType expected);
  error Message__InvalidMsgLength(uint256 actual, uint256 expected);

  uint256 public constant LEN_MSG_INITIALIZE_ASSET = 33;
  uint256 public constant LEN_MSG_DEPOSIT = 97;
  uint256 public constant LEN_MSG_DEPOSIT_WITH_MATRIX_SUPPLY = 129;
  uint256 public constant LEN_MSG_REDEEM = 97;
  uint256 public constant LEN_MSG_INITIALIZE_MATRIX = 65;
  uint256 public constant LEN_MSG_ALLOCATE_MATRIX_LIQUIDITY = 65;
  uint256 public constant LEN_MSG_DEALLOCATE_MATRIX_LIQUIDITY = 65;
  uint256 public constant LEN_MSG_SETTLE_MATRIX_YIELD = 65;
  uint256 public constant LEN_MSG_SETTLE_MATRIX_LOSS = 65;
  uint256 public constant LEN_MSG_SETTLE_MATRIX_EXTRA_REWARDS = 97;

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

  function encode(MsgDepositWithMatrixSupply memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(
      uint8(MsgType.MsgDepositWithMatrixSupply), msg_.asset, msg_.to, msg_.matrixBasketAsset, msg_.amount
    );
  }

  function decodeDepositWithMatrixSupply(bytes calldata msg_)
    internal
    pure
    returns (MsgDepositWithMatrixSupply memory decoded)
  {
    assertMsg(msg_, MsgType.MsgDepositWithMatrixSupply, LEN_MSG_DEPOSIT_WITH_MATRIX_SUPPLY);

    decoded.asset = bytes32(msg_[1:33]);
    decoded.to = bytes32(msg_[33:65]);
    decoded.matrixBasketAsset = bytes32(msg_[65:97]);
    decoded.amount = uint256(bytes32(msg_[97:]));
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

  function encode(MsgInitializeMatrix memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgInitializeMatrix), msg_.matrixBasketAsset, msg_.asset);
  }

  function decodeInitializeMatrix(bytes calldata msg_) internal pure returns (MsgInitializeMatrix memory decoded) {
    assertMsg(msg_, MsgType.MsgInitializeMatrix, LEN_MSG_INITIALIZE_MATRIX);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.asset = bytes32(msg_[33:]);
  }

  function encode(MsgAllocateMatrixLiquidity memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgAllocateMatrixLiquidity), msg_.matrixBasketAsset, msg_.amount);
  }

  function decodeAllocateMatrixLiquidity(bytes calldata msg_)
    internal
    pure
    returns (MsgAllocateMatrixLiquidity memory decoded)
  {
    assertMsg(msg_, MsgType.MsgAllocateMatrixLiquidity, LEN_MSG_ALLOCATE_MATRIX_LIQUIDITY);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgDeallocateMatrixLiquidity memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgDeallocateMatrixLiquidity), msg_.matrixBasketAsset, msg_.amount);
  }

  function decodeDeallocateMatrixLiquidity(bytes calldata msg_)
    internal
    pure
    returns (MsgDeallocateMatrixLiquidity memory decoded)
  {
    assertMsg(msg_, MsgType.MsgDeallocateMatrixLiquidity, LEN_MSG_DEALLOCATE_MATRIX_LIQUIDITY);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixYield memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleMatrixYield), msg_.matrixBasketAsset, msg_.amount);
  }

  function decodeSettleYield(bytes calldata msg_) internal pure returns (MsgSettleMatrixYield memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleMatrixYield, LEN_MSG_SETTLE_MATRIX_YIELD);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixLoss memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleMatrixLoss), msg_.matrixBasketAsset, msg_.amount);
  }

  function decodeSettleLoss(bytes calldata msg_) internal pure returns (MsgSettleMatrixLoss memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleMatrixLoss, LEN_MSG_SETTLE_MATRIX_LOSS);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixExtraRewards memory msg_) internal pure returns (bytes memory) {
    return
      abi.encodePacked(uint8(MsgType.MsgSettleMatrixExtraRewards), msg_.matrixBasketAsset, msg_.reward, msg_.amount);
  }

  function decodeSettleExtraRewards(bytes calldata msg_)
    internal
    pure
    returns (MsgSettleMatrixExtraRewards memory decoded)
  {
    assertMsg(msg_, MsgType.MsgSettleMatrixExtraRewards, LEN_MSG_SETTLE_MATRIX_EXTRA_REWARDS);

    decoded.matrixBasketAsset = bytes32(msg_[1:33]);
    decoded.reward = bytes32(msg_[33:65]);
    decoded.amount = uint256(bytes32(msg_[65:]));
  }
}
