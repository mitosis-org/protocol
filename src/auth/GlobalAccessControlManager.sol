// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable2StepUpgradeable } from '@ozu-v5/access/Ownable2StepUpgradeable.sol';

import { EnumerableSet } from '@oz-v5/utils/structs/EnumerableSet.sol';

import { IGlobalAccessControlManager } from '../interfaces/auth/IGlobalAccessControlManager.sol';
import { ERC7201Utils } from '../lib/ERC7201Utils.sol';
import { StdError } from '../lib/StdError.sol';

contract GlobalAccessControlManager is IGlobalAccessControlManager, Ownable2StepUpgradeable {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using ERC7201Utils for string;

  struct PauseData {
    /// @dev Complete pause for the contract.
    bool global_;
    /// @dev Complete pause for the given signature.
    mapping(bytes4 sig => bool isPaused) paused;
    /// @dev Pause for the given signature with parameters.
    mapping(bytes4 sig => EnumerableSet.Bytes32Set params) paramFilters;
  }

  struct RoleData {
    mapping(address account => bool isAdmin) admins;
    mapping(address account => mapping(bytes4 sig => bool auth)) hasRole;
  }

  struct GlobalAccessControlManagerStorage {
    address globalAccessControlManager;
    /// @dev `*Managers` stands for authorization to grant permissions to other contracts.
    mapping(address target => RoleData pauseRole) pauseManagers;
    mapping(address target => RoleData grantRole) roleManagers;
    //
    mapping(address target => PauseData pauseData) pauses;
    mapping(address target => RoleData role) roles;
  }

  string private constant _NAMESPACE = 'mitosis.storage.GloablAccessControlManager';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getGlobalAccessControlManagerStorage() private view returns (GlobalAccessControlManagerStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  constructor() {
    _disableInitializers();
  }

  modifier onlyGlobalAccessControlManager() {
    require(_msgSender() == _getGlobalAccessControlManagerStorage().globalAccessControlManager, StdError.Unauthorized());
    _;
  }

  function initialize(address owner_, address globalAccessControlManager_) public initializer {
    __Ownable2Step_init();
    _transferOwnership(owner_);
    _getGlobalAccessControlManagerStorage().globalAccessControlManager = globalAccessControlManager_;
  }

  // =========================== NOTE: VIEW FUNCTIONS =========================== //

  function globalAccessControlManager() external view returns (address) {
    return _getGlobalAccessControlManagerStorage().globalAccessControlManager;
  }

  function isGlobalAccessControlManager(address target) external view returns (bool) {
    return _getGlobalAccessControlManagerStorage().globalAccessControlManager == target;
  }

  function hasAdminRole(address target, address account) external view returns (bool) {
    return _hasAdminRole(_getGlobalAccessControlManagerStorage().roles[target], account);
  }

  function hasManagerRole(address target, address account) external view returns (bool) {
    return _hasAdminRole(_getGlobalAccessControlManagerStorage().roleManagers[target], account);
  }

  function hasManagerRole(address target, bytes4 sig, address account) external view returns (bool) {
    return _hasRole(_getGlobalAccessControlManagerStorage().roleManagers[target], sig, account);
  }

  function hasPauseRole(address target, address account) external view returns (bool) {
    return _hasAdminRole(_getGlobalAccessControlManagerStorage().pauseManagers[target], account);
  }

  function hasPauseRole(address target, bytes4 sig, address account) external view returns (bool) {
    return _hasRole(_getGlobalAccessControlManagerStorage().pauseManagers[target], sig, account);
  }

  function hasRole(address target, bytes4 sig, address account) external view returns (bool) {
    return _hasRole(_getGlobalAccessControlManagerStorage().roles[target], sig, account);
  }

  function isPaused(address target, bytes4 sig) external view returns (bool) {
    return _isPaused(target, sig);
  }

  function isPaused(address target, bytes4 sig, bytes32 params) external view returns (bool) {
    return _isPaused(target, sig, params);
  }

  function isPausedGlobally(address target) external view returns (bool) {
    return _isPausedGlobally(target);
  }

  function assertHasRole(address target, bytes4 sig, address account) external view {
    require(_hasRole(_getGlobalAccessControlManagerStorage().roles[target], sig, account), StdError.Unauthorized());
  }

  function assertHasNotRole(address target, bytes4 sig, address account) external view {
    require(!_hasRole(_getGlobalAccessControlManagerStorage().roles[target], sig, account), StdError.Unauthorized());
  }

  function assertAdmin(address target, address account) external view {
    require(_hasAdminRole(_getGlobalAccessControlManagerStorage().roles[target], account), StdError.Unauthorized());
  }

  function assertNotAdmin(address target, address account) external view {
    require(!_hasAdminRole(_getGlobalAccessControlManagerStorage().roles[target], account), StdError.Unauthorized());
  }

  function assertNotPaused(address target, bytes4 sig) external view {
    require(!_isPaused(target, sig), IGlobalAccessControlManager__Paused(sig));
  }

  function assertNotPaused(address target, bytes4 sig, bytes32 params) external view {
    require(!_isPaused(target, sig, params), IGlobalAccessControlManager__Paused(sig));
  }

  function assertPaused(address target, bytes4 sig) external view {
    require(_isPaused(target, sig), IGlobalAccessControlManager__NotPaused(sig));
  }

  function assertPaused(address target, bytes4 sig, bytes32 params) external view {
    require(_isPaused(target, sig, params), IGlobalAccessControlManager__NotPaused(sig));
  }

  // =========================== NOTE: MUTATIVE FUNCTIONS =========================== //

  function setGlobalAccessControlManager(address newGlobalAccessControlManager) external onlyGlobalAccessControlManager {
    _getGlobalAccessControlManagerStorage().globalAccessControlManager = newGlobalAccessControlManager;
    emit GlobalAccessControlManagerSet(newGlobalAccessControlManager);
  }

  function grantRoleManager(address target, bytes4 sig, address manager) external onlyGlobalAccessControlManager {
    _grant(_getGlobalAccessControlManagerStorage().roleManagers[target], sig, manager);
    emit RoleManagerGranted(target, sig, manager);
  }

  function grantRoleManager(address target, address manager) external onlyGlobalAccessControlManager {
    _grantAdmin(_getGlobalAccessControlManagerStorage().roleManagers[target], manager);
    emit AdminRoleManagerGranted(target, manager);
  }

  function grantPauseManager(address target, bytes4 sig, address manager) external onlyGlobalAccessControlManager {
    _grant(_getGlobalAccessControlManagerStorage().pauseManagers[target], sig, manager);
    emit PauseManagerGranted(target, sig, manager);
  }

  function grantPauseManager(address target, address manager) external onlyGlobalAccessControlManager {
    _grantAdmin(_getGlobalAccessControlManagerStorage().pauseManagers[target], manager);
    emit AdminPauseManagerGranted(target, manager);
  }

  function revokeRoleManager(address target, bytes4 sig, address manager) external onlyGlobalAccessControlManager {
    _revoke(_getGlobalAccessControlManagerStorage().roleManagers[target], sig, manager);
    emit RoleManagerRevoked(target, sig, manager);
  }

  function revokeRoleManager(address target, address manager) external onlyGlobalAccessControlManager {
    _revokeAdmin(_getGlobalAccessControlManagerStorage().roleManagers[target], manager);
    emit AdminRoleManagerRevoked(target, manager);
  }

  function revokePauseManager(address target, bytes4 sig, address manager) external onlyGlobalAccessControlManager {
    _revoke(_getGlobalAccessControlManagerStorage().pauseManagers[target], sig, manager);
    emit PauseManagerRevoked(target, sig, manager);
  }

  function revokePauseManager(address target, address manager) external onlyGlobalAccessControlManager {
    _revokeAdmin(_getGlobalAccessControlManagerStorage().pauseManagers[target], manager);
    emit AdminPauseManagerRevoked(target, manager);
  }

  function grantAdmin(address target, address account) external {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();
    _assertManagerAuthority($, target);
    _grantAdmin($.roles[target], account);
    emit AdminRoleGranted(target, account);
  }

  function grant(address target, bytes4 sig, address account) public {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();
    _assertManagerAuthority($, target, sig);
    _grant($.roles[target], sig, account);
    emit RoleGranted(target, sig, account);
  }

  function grant(address target, bytes4[] calldata sigs, address account) external {
    for (uint256 i = 0; i < sigs.length; i++) {
      grant(target, sigs[i], account);
    }
  }

  function revokeAdmin(address target, address account) external {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();
    _assertManagerAuthority($, target);
    _revokeAdmin($.roles[target], account);
    emit AdminRoleRevoked(target, account);
  }

  function revoke(address target, bytes4 sig, address account) public {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();
    _assertManagerAuthority($, target, sig);
    _revoke($.roles[target], sig, account);
    emit RoleRevoked(target, sig, account);
  }

  function revoke(address target, bytes4[] calldata sigs, address account) external {
    for (uint256 i = 0; i < sigs.length; i++) {
      revoke(target, sigs[i], account);
    }
  }

  function pause(address target) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target);
    _pause(target);
    emit GlobalPaused(target);
  }

  function pause(address target, bytes4 sig) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target, sig);
    _pause(target, sig);
    emit Paused(target, sig);
  }

  function pause(address target, bytes4 sig, bytes32 param) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target, sig);
    _pause(target, sig, param);
    emit PausedWithParamFilter(target, sig, param);
  }

  function unpause(address target) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target);
    _unpause(target);
    emit GlobalUnpaused(target);
  }

  function unpause(address target, bytes4 sig) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target, sig);
    _unpause(target, sig);
    emit Unpaused(target, sig);
  }

  function unpause(address target, bytes4 sig, bytes32 param) external {
    _assertPausable(_getGlobalAccessControlManagerStorage(), target, sig);
    _unpause(target, sig, param);
    emit UnpausedWithParamFilter(target, sig, param);
  }

  // =========================== NOTE: INTERNAL FUNCTIONS =========================== //

  function _grantAdmin(RoleData storage roleData, address account) internal {
    roleData.admins[account] = true;
  }

  function _grant(RoleData storage roleData, bytes4 sig, address account) internal {
    roleData.hasRole[account][sig] = true;
  }

  function _revokeAdmin(RoleData storage roleData, address account) internal {
    roleData.admins[account] = false;
  }

  function _revoke(RoleData storage roleData, bytes4 sig, address account) internal {
    roleData.hasRole[account][sig] = true;
  }

  function _pause(address target) internal virtual {
    _getGlobalAccessControlManagerStorage().pauses[target].global_ = true;
  }

  function _pause(address target, bytes4 sig) internal virtual {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();

    $.pauses[target].paused[sig] = true;

    EnumerableSet.Bytes32Set storage paramFilter = $.pauses[target].paramFilters[sig];
    for (uint256 i = 0; i < paramFilter.length(); i++) {
      paramFilter.remove(paramFilter.at(i));
    }
  }

  function _pause(address target, bytes4 sig, bytes32 param) internal {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();
    if ($.pauses[target].paused[sig]) return;
    $.pauses[target].paramFilters[sig].add(param);
  }

  function _unpause(address target) internal virtual {
    _getGlobalAccessControlManagerStorage().pauses[target].global_ = false;
  }

  function _unpause(address target, bytes4 sig) internal virtual {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();

    $.pauses[target].paused[sig] = false;

    EnumerableSet.Bytes32Set storage paramFilter = $.pauses[target].paramFilters[sig];
    for (uint256 i = 0; i < paramFilter.length(); i++) {
      paramFilter.remove(paramFilter.at(i));
    }
  }

  function _unpause(address target, bytes4 sig, bytes32 param) internal {
    GlobalAccessControlManagerStorage storage $ = _getGlobalAccessControlManagerStorage();

    EnumerableSet.Bytes32Set storage paramFilter = $.pauses[target].paramFilters[sig];
    if (paramFilter.contains(param)) {
      paramFilter.remove(param);
    }
  }

  function _hasAdminRole(RoleData storage roleData, address account) internal view returns (bool) {
    return roleData.admins[account];
  }

  function _hasRole(RoleData storage roleData, bytes4 sig, address account) internal view virtual returns (bool) {
    return roleData.admins[account] || roleData.hasRole[account][sig];
  }

  function _isPaused(address target, bytes4 sig) internal view virtual returns (bool) {
    PauseData storage pauseData = _getGlobalAccessControlManagerStorage().pauses[target];
    require(pauseData.paramFilters[sig].length() == 0, '');
    return pauseData.global_ || pauseData.paused[sig];
  }

  function _isPaused(address target, bytes4 sig, bytes32 param) internal view returns (bool) {
    PauseData storage pauseData = _getGlobalAccessControlManagerStorage().pauses[target];
    if (pauseData.global_ || pauseData.paused[sig]) return true;
    return pauseData.paramFilters[sig].contains(param);
  }

  function _isPausedGlobally(address target) internal view virtual returns (bool) {
    return _getGlobalAccessControlManagerStorage().pauses[target].global_;
  }

  function _assertManagerAuthority(GlobalAccessControlManagerStorage storage $, address target, bytes4 sig)
    internal
    view
  {
    address msgSender = _msgSender();
    if ($.globalAccessControlManager == msgSender) return;
    if ($.roleManagers[target].admins[msgSender]) return;
    require($.roleManagers[target].hasRole[msgSender][sig], StdError.Unauthorized());
  }

  function _assertManagerAuthority(GlobalAccessControlManagerStorage storage $, address target) internal view {
    address msgSender = _msgSender();
    if ($.globalAccessControlManager == msgSender) return;
    require($.roleManagers[target].admins[msgSender], StdError.Unauthorized());
  }

  function _assertPausable(GlobalAccessControlManagerStorage storage $, address target, bytes4 sig) internal view {
    address msgSender = _msgSender();
    if ($.globalAccessControlManager == msgSender) return;
    if ($.pauseManagers[target].admins[msgSender]) return;
    require($.pauseManagers[target].hasRole[msgSender][sig], StdError.Unauthorized());
  }

  function _assertPausable(GlobalAccessControlManagerStorage storage $, address target) internal view {
    address msgSender = _msgSender();
    if ($.globalAccessControlManager == msgSender) return;
    require($.pauseManagers[target].admins[msgSender], StdError.Unauthorized());
  }
}
