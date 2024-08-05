// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from '@oz-v5/token/ERC20/IERC20.sol';
import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { IMitosisVaultEntrypoint } from '@src/interfaces/branch/IMitosisVaultEntrypoint.sol';

enum Action {
  Deposit
}

contract MitosisVaultStorageV1 {
  // TODO(thai): change location
  /// @custom:storage-location erc7201:mitosis.storage.BasicVault.v1
  struct StorageV1 {
    IERC20 asset;
    uint8 underlyingDecimals;
    mapping(Action => bool) isHalted;
    mapping(address => mapping(Action => bool)) isAllowed;
  }

  // keccak256(abi.encode(uint256(keccak256("mitosis.storage.BasicVault.v1")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 public constant StorageV1Location = 0xdfd1d7385a5871446aad353015e13a89d148fc3945543ae58683c6905a730600;

  function _getStorageV1() internal pure returns (StorageV1 storage $) {
    // slither-disable-next-line assembly
    assembly {
      $.slot := StorageV1Location
    }
  }
}

contract MitosisVault is OwnableUpgradeable {
  struct AssetInfo {
    bool initialized;
    mapping(Action => bool) isHalted;
    uint256 eolAllocated;
  }

  mapping(address asset => AssetInfo) public assets;

  IMitosisVaultEntrypoint entrypoint;

  modifier assetInitialized(address asset) {
    if (!assets[asset].initialized) {
      revert('must be initialized');
    }
    _;
  }

  modifier onlyEntrypoint() {
    require(msg.sender == address(entrypoint), 'only entrypoint can call this function');

    _;
  }

  modifier withNoHalt(address asset, Action action) {
    if (assets[asset].isHalted[action]) {
      revert('action halted');
    }

    _;
  }

  function initializeAsset(address asset, bool enableDeposit) external onlyEntrypoint {
    require(!assets[asset].initialized, 'already initialized');

    assets[asset].initialized = true;
    if (!enableDeposit) {
      assets[asset].isHalted[Action.Deposit] = true;
    }
  }

  function deposit(address asset, address to, uint256 amount)
    external
    assetInitialized(asset)
    withNoHalt(asset, Action.Deposit)
  {
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    entrypoint.mint(asset, to, amount);
  }

  function redeem(address asset, address to, uint256 amount) external onlyEntrypoint assetInitialized(asset) {
    IERC20(asset).transfer(to, amount);
  }

  //////////////////////////
  // Admin functions
  //////////////////////////

  function halt(Action action) external {
    assets[msg.sender].isHalted[action] = true;
  }

  function resume(Action action) external {
    assets[msg.sender].isHalted[action] = false;
  }
}
