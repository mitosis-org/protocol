// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.23 <0.9.0;

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';

interface IEOLVaultFactory {
  enum VaultType {
    Unset,
    Basic
  }

  struct BasicVaultInitArgs {
    address assetManager;
    IERC20Metadata asset;
    string name;
    string symbol;
  }

  event VaultTypeInitialized(VaultType indexed vaultType, address indexed beacon);
  event EOLVaultCreated(VaultType indexed vaultType, address indexed instance, bytes initArgs);
  event EOLVaultMigrated(VaultType indexed from, VaultType indexed to, address indexed instance);
  event BeaconCalled(address indexed caller, VaultType indexed vaultType, bytes data, bool success, bytes ret);

  error IEOLVaultFactory__AlreadyInitialized();
  error IEOLVaultFactory__NotInitialized();
  error IEOLVaultFactory__NotAnInstance();
  error IEOLVaultFactory__InvalidVaultType();
  error IEOLVaultFactory__CallBeaconFailed(bytes ret);

  function beacon(uint8 t) external view returns (address);
  function isInstance(address instance) external view returns (bool);
  function isInstance(uint8 t, address instance) external view returns (bool);
  function instances(uint8 t, uint256 index) external view returns (address);
  function instances(uint8 t, uint256[] memory indexes) external view returns (address[] memory);
  function instancesLength(uint8 t) external view returns (uint256);
  function vaultTypeInitialized(uint8 t) external view returns (bool);

  function callBeacon(uint8 t, bytes calldata data) external returns (bytes memory);
  function create(uint8 t, bytes calldata args) external returns (address);
  function migrate(uint8 from, uint8 to, address instance, bytes calldata data) external;
}
