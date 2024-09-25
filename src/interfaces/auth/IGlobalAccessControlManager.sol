// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IGlobalAccessControlManager {
  event GlobalAccessControlManagerSet(address indexed newGlobalAccessControlManager);

  event AdminRoleManagerGranted(address indexed target, address indexed account);
  event AdminRoleManagerRevoked(address indexed target, address indexed account);
  event RoleManagerGranted(address indexed target, bytes4 indexed sig, address indexed account);
  event RoleManagerRevoked(address indexed target, bytes4 indexed sig, address indexed account);

  event AdminPauseManagerGranted(address indexed target, address indexed account);
  event AdminPauseManagerRevoked(address indexed target, address indexed account);
  event PauseManagerGranted(address indexed target, bytes4 indexed sig, address indexed account);
  event PauseManagerRevoked(address indexed target, bytes4 indexed sig, address indexed account);

  event AdminRoleGranted(address indexed target, address indexed account);
  event AdminRoleRevoked(address indexed target, address indexed account);
  event RoleGranted(address indexed target, bytes4 indexed sig, address indexed account);
  event RoleRevoked(address indexed target, bytes4 indexed sig, address indexed account);

  event GlobalPaused(address indexed target);
  event GlobalUnpaused(address indexed target);
  event Paused(address indexed target, bytes4 indexed sig);
  event Unpaused(address indexed target, bytes4 indexed sig);
  event PausedWithParamFilter(address indexed target, bytes4 indexed sig, bytes32 indexed param);
  event UnpausedWithParamFilter(address indexed target, bytes4 indexed sig, bytes32 indexed param);

  error IGlobalAccessControlManager__Paused(bytes4 sig);
  error IGlobalAccessControlManager__NotPaused(bytes4 sig);

  function globalAccessControlManager() external view returns (address);
  function isGlobalAccessControlManager(address target) external view returns (bool);
  function hasManagerRole(address target) external view returns (bool);
  function hasManagerRole(address target, address account) external view returns (bool);
  function hasManagerRole(address target, bytes4 sig, address account) external view returns (bool);
  function hasPauseRole(address target) external view returns (bool);
  function hasPauseRole(address target, address account) external view returns (bool);
  function hasPauseRole(address target, bytes4 sig, address account) external view returns (bool);
  function hasAdminRole(address target) external view returns (bool);
  function hasAdminRole(address target, address account) external view returns (bool);
  function hasRole(address target, bytes4 sig) external view returns (bool);
  function hasRole(address target, bytes4 sig, address account) external view returns (bool);
  function isPaused(address target, bytes4 sig) external view returns (bool);
  function isPaused(address target, bytes4 sig, bytes32 param) external view returns (bool);
  function isPausedGlobally(address target) external view returns (bool);

  function assertHasRole(address target, bytes4 sig, address account) external view;
  function assertHasNotRole(address target, bytes4 sig, address account) external view;
  function assertAdmin(address target, address account) external view;
  function assertNotAdmin(address target, address account) external view;
  function assertNotPaused(address target, bytes4 sig) external view;
  function assertNotPaused(address target, bytes4 sig, bytes32 param) external view;
  function assertPaused(address target, bytes4 sig) external view;
  function assertPaused(address target, bytes4 sig, bytes32 param) external view;

  function setGlobalAccessControlManager(address newGlobalAccessControlManager) external;
  function grantRoleManager(address target, bytes4 sig, address manager) external;
  function grantRoleManager(address target, address manager) external;
  function grantPauseManager(address target, bytes4 sig, address manager) external;
  function grantPauseManager(address target, address manager) external;
  function revokeRoleManager(address target, bytes4 sig, address manager) external;
  function revokeRoleManager(address target, address manager) external;
  function revokePauseManager(address target, bytes4 sig, address manager) external;
  function revokePauseManager(address target, address manager) external;

  function grantAdmin(address target, address account) external;
  function grant(address target, bytes4 sig, address account) external;
  function grant(address target, bytes4[] calldata sigs, address account) external;
  function revokeAdmin(address target, address account) external;
  function revoke(address target, bytes4 sig, address account) external;
  function revoke(address target, bytes4[] calldata sigs, address account) external;
  function pause(address target) external;
  function pause(address target, bytes4 sig) external;
  function pause(address target, bytes4 sig, bytes32 param) external;
  function unpause(address target) external;
  function unpause(address target, bytes4 sig) external;
  function unpause(address target, bytes4 sig, bytes32 param) external;
}
