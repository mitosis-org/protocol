// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

enum MsgType {
  //=========== NOTE: Asset ===========//
  MsgInitializeAsset,
  MsgDeposit,
  MsgDepositWithSupplyMatrix,
  MsgRedeem,
  //=========== NOTE: Matrix ===========//
  MsgInitializeMatrix,
  MsgAllocateMatrix,
  MsgDeallocateMatrix,
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
struct MsgDepositWithSupplyMatrix {
  bytes32 asset;
  bytes32 to;
  bytes32 matrixVault;
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
  bytes32 matrixVault;
  bytes32 asset;
}

// hub -> branch
struct MsgAllocateMatrix {
  bytes32 matrixVault;
  uint256 amount;
}

// branch -> hub
struct MsgDeallocateMatrix {
  bytes32 matrixVault;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixYield {
  bytes32 matrixVault;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixLoss {
  bytes32 matrixVault;
  uint256 amount;
}

// branch -> hub
struct MsgSettleMatrixExtraRewards {
  bytes32 matrixVault;
  bytes32 reward;
  uint256 amount;
}

library Message {
  error Message__InvalidMsgType(MsgType actual, MsgType expected);
  error Message__InvalidMsgLength(uint256 actual, uint256 expected);

  uint256 public constant LEN_MSG_INITIALIZE_ASSET = 33;
  uint256 public constant LEN_MSG_DEPOSIT = 97;
  uint256 public constant LEN_MSG_DEPOSIT_WITH_SUPPLY_MATRIX = 129;
  uint256 public constant LEN_MSG_REDEEM = 97;
  uint256 public constant LEN_MSG_INITIALIZE_MATRIX = 65;
  uint256 public constant LEN_MSG_ALLOCATE_MATRIX = 65;
  uint256 public constant LEN_MSG_DEALLOCATE_MATRIX = 65;
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

  function encode(MsgDepositWithSupplyMatrix memory msg_) internal pure returns (bytes memory) {
    return
      abi.encodePacked(uint8(MsgType.MsgDepositWithSupplyMatrix), msg_.asset, msg_.to, msg_.matrixVault, msg_.amount);
  }

  function decodeDepositWithSupplyMatrix(bytes calldata msg_)
    internal
    pure
    returns (MsgDepositWithSupplyMatrix memory decoded)
  {
    assertMsg(msg_, MsgType.MsgDepositWithSupplyMatrix, LEN_MSG_DEPOSIT_WITH_SUPPLY_MATRIX);

    decoded.asset = bytes32(msg_[1:33]);
    decoded.to = bytes32(msg_[33:65]);
    decoded.matrixVault = bytes32(msg_[65:97]);
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
    return abi.encodePacked(uint8(MsgType.MsgInitializeMatrix), msg_.matrixVault, msg_.asset);
  }

  function decodeInitializeMatrix(bytes calldata msg_) internal pure returns (MsgInitializeMatrix memory decoded) {
    assertMsg(msg_, MsgType.MsgInitializeMatrix, LEN_MSG_INITIALIZE_MATRIX);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.asset = bytes32(msg_[33:]);
  }

  function encode(MsgAllocateMatrix memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgAllocateMatrix), msg_.matrixVault, msg_.amount);
  }

  function decodeAllocateMatrix(bytes calldata msg_) internal pure returns (MsgAllocateMatrix memory decoded) {
    assertMsg(msg_, MsgType.MsgAllocateMatrix, LEN_MSG_ALLOCATE_MATRIX);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgDeallocateMatrix memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgDeallocateMatrix), msg_.matrixVault, msg_.amount);
  }

  function decodeDeallocateMatrix(bytes calldata msg_) internal pure returns (MsgDeallocateMatrix memory decoded) {
    assertMsg(msg_, MsgType.MsgDeallocateMatrix, LEN_MSG_DEALLOCATE_MATRIX);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixYield memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleMatrixYield), msg_.matrixVault, msg_.amount);
  }

  function decodeSettleMatrixYield(bytes calldata msg_) internal pure returns (MsgSettleMatrixYield memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleMatrixYield, LEN_MSG_SETTLE_MATRIX_YIELD);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixLoss memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleMatrixLoss), msg_.matrixVault, msg_.amount);
  }

  function decodeSettleMatrixLoss(bytes calldata msg_) internal pure returns (MsgSettleMatrixLoss memory decoded) {
    assertMsg(msg_, MsgType.MsgSettleMatrixLoss, LEN_MSG_SETTLE_MATRIX_LOSS);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.amount = uint256(bytes32(msg_[33:]));
  }

  function encode(MsgSettleMatrixExtraRewards memory msg_) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(MsgType.MsgSettleMatrixExtraRewards), msg_.matrixVault, msg_.reward, msg_.amount);
  }

  function decodeSettleMatrixExtraRewards(bytes calldata msg_)
    internal
    pure
    returns (MsgSettleMatrixExtraRewards memory decoded)
  {
    assertMsg(msg_, MsgType.MsgSettleMatrixExtraRewards, LEN_MSG_SETTLE_MATRIX_EXTRA_REWARDS);

    decoded.matrixVault = bytes32(msg_[1:33]);
    decoded.reward = bytes32(msg_[33:65]);
    decoded.amount = uint256(bytes32(msg_[65:]));
  }
}
