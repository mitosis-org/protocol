// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC7201Utils } from './ERC7201Utils.sol';

contract Pausable {
  using ERC7201Utils for string;

  /// @custom:storage-location mitosis.storage.Pausable
  struct PausableStorage {
    bool global_;
    mapping(bytes4 sig => bool isPaused) paused;
  }

  error Pausable__Paused(bytes4 sig);
  error Pausable__NotPaused(bytes4 sig);

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  string private constant _NAMESPACE = 'mitosis.storage.Pausable';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getPausableStorage() private view returns (PausableStorage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  modifier notPaused() {
    _assertNotPaused();
    _;
  }

  // =========================== NOTE: INITIALIZE HELPERS =========================== //

  function __Pausable_init() internal {
    PausableStorage storage $ = _getPausableStorage();

    $.global_ = false;
  }

  // =========================== NOTE: MAIN FUNCTIONS =========================== //

  function isPaused(bytes4 sig) external view returns (bool) {
    return _isPaused(sig);
  }

  function isPausedGlobally() external view returns (bool) {
    return _isPausedGlobally();
  }

  function _pause() internal virtual {
    _getPausableStorage().global_ = true;
  }

  function _pause(bytes4 sig) internal virtual {
    _getPausableStorage().paused[sig] = true;
  }

  function _unpause() internal virtual {
    _getPausableStorage().global_ = false;
  }

  function _unpause(bytes4 sig) internal virtual {
    _getPausableStorage().paused[sig] = false;
  }

  function _isPaused(bytes4 sig) internal view virtual returns (bool) {
    PausableStorage storage $ = _getPausableStorage();

    return $.global_ || $.paused[sig];
  }

  function _isPausedGlobally() internal view virtual returns (bool) {
    return _getPausableStorage().global_;
  }

  function _assertNotPaused() internal view virtual {
    _assertNotPaused(msg.sig);
  }

  function _assertNotPaused(bytes4 sig) internal view virtual {
    require(!_isPaused(sig), Pausable__Paused(sig));
  }

  function _assertPaused() internal view virtual {
    _assertPaused(msg.sig);
  }

  function _assertPaused(bytes4 sig) internal view virtual {
    require(_isPaused(sig), Pausable__NotPaused(sig));
  }
}
