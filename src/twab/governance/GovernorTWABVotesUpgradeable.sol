// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/extensions/GovernorVotes.sol)

// Modified to work with {ITWABSnapshots}.
pragma solidity ^0.8.26;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';
import { Initializable } from '@ozu-v5/proxy/utils/Initializable.sol';

import { ITWABSnapshots } from '../../interfaces/twab/ITWABSnapshots.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { StdError } from '../../lib/StdError.sol';
import { TWABSnapshotsUtils } from '../../lib/TWABSnapshotsUtils.sol';

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ITWABSnapshots} token.
 */
abstract contract GovernorTWABVotesUpgradeable is Initializable, GovernorUpgradeable {
  using ERC7201Utils for string;
  using TWABSnapshotsUtils for ITWABSnapshots;

  struct GovernorTWABVotesStorage {
    ITWABSnapshots token;
    uint32 twabPeriod;
  }

  string constant _GovernorTWABVotesStorageNamespace = 'mitosis.storage.GovernorTWABVotes';
  bytes32 private immutable _GovernorTWABVotesStorageLocation = _GovernorTWABVotesStorageNamespace.storageSlot();

  function _getGovernorTWABVotesStorage() private view returns (GovernorTWABVotesStorage storage $) {
    bytes32 slot = _GovernorTWABVotesStorageLocation;
    assembly {
      $.slot := slot
    }
  }

  function __GovernorTWABVotes_init(ITWABSnapshots token_, uint32 twabPeriod_) internal onlyInitializing {
    __GovernorTWABVotes_init_unchained(token_, twabPeriod_);
  }

  function __GovernorTWABVotes_init_unchained(ITWABSnapshots token_, uint32 twabPeriod_) internal onlyInitializing {
    GovernorTWABVotesStorage storage $ = _getGovernorTWABVotesStorage();
    $.token = token_;
    $.twabPeriod = twabPeriod_;
  }

  /**
   * @dev The token that voting power is sourced from.
   */
  function token() public view returns (ITWABSnapshots) {
    GovernorTWABVotesStorage storage $ = _getGovernorTWABVotesStorage();
    return $.token;
  }

  /**
   * @dev The period of time in seconds for which the voting power is calculated.
   */
  function twabPeriod() external view returns (uint32) {
    GovernorTWABVotesStorage storage $ = _getGovernorTWABVotesStorage();
    return $.twabPeriod;
  }

  /**
   * @dev Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
   * does not implement EIP-6372.
   */
  function clock() public view virtual override returns (uint48) {
    return token().clock();
  }

  /**
   * @dev Machine-readable description of the clock as specified in EIP-6372.
   */
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual override returns (string memory) {
    return token().CLOCK_MODE();
  }

  /**
   * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
   */
  function _getVotes(address account, uint256 timepoint, bytes memory /*params*/ )
    internal
    view
    virtual
    override
    returns (uint256)
  {
    return _getVotingPower(account, timepoint);
  }

  function _getVotingPower(address account, uint256 timepoint) internal view virtual returns (uint256) {
    GovernorTWABVotesStorage storage $ = _getGovernorTWABVotesStorage();
    return $.token.getAccountTWABByTimestampRange(
      account, SafeCast.toUint48(timepoint - $.twabPeriod), SafeCast.toUint48(timepoint)
    );
  }

  function _getTotalVotingPower(uint256 timepoint) internal view virtual returns (uint256) {
    GovernorTWABVotesStorage storage $ = _getGovernorTWABVotesStorage();
    return
      $.token.getTotalTWABByTimestampRange(SafeCast.toUint48(timepoint - $.twabPeriod), SafeCast.toUint48(timepoint));
  }
}
