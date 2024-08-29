// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/extensions/GovernorVotes.sol)

// Modified to work with {ITwabSnapshots}.
pragma solidity ^0.8.26;

import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { GovernorUpgradeable } from '@ozu-v5/governance/GovernorUpgradeable.sol';
import { Initializable } from '@ozu-v5/proxy/utils/Initializable.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { ITwabSnapshots } from '../../interfaces/twab/ITwabSnapshots.sol';
import { StdError } from '../../lib/StdError.sol';
import { TwabSnapshotsUtils } from '../../lib/TwabSnapshotsUtils.sol';

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ITwabSnapshots} token.
 */
abstract contract GovernorTwabVotesUpgradeable is Initializable, GovernorUpgradeable {
  using ERC7201Utils for string;
  using TwabSnapshotsUtils for ITwabSnapshots;

  struct GovernorTwabVotesStorage {
    ITwabSnapshots token;
    uint32 twabPeriod;
  }

  string constant _GovernorTwabVotesStorageNamespace = 'mitosis.storage.GovernorTwabVotes';
  bytes32 private immutable _GovernorTwabVotesStorageLocation = _GovernorTwabVotesStorageNamespace.storageSlot();

  function _getGovernorTwabVotesStorage() private view returns (GovernorTwabVotesStorage storage $) {
    bytes32 slot = _GovernorTwabVotesStorageLocation;
    assembly {
      $.slot := slot
    }
  }

  function __GovernorTwabVotes_init(ITwabSnapshots token_, uint32 twabPeriod_) internal onlyInitializing {
    __GovernorTwabVotes_init_unchained(token_, twabPeriod_);
  }

  function __GovernorTwabVotes_init_unchained(ITwabSnapshots token_, uint32 twabPeriod_) internal onlyInitializing {
    GovernorTwabVotesStorage storage $ = _getGovernorTwabVotesStorage();
    $.token = token_;
    $.twabPeriod = twabPeriod_;
  }

  /**
   * @dev The token that voting power is sourced from.
   */
  function token() public view returns (ITwabSnapshots) {
    GovernorTwabVotesStorage storage $ = _getGovernorTwabVotesStorage();
    return $.token;
  }

  /**
   * @dev The period of time in seconds for which the voting power is calculated.
   */
  function twabPeriod() external view returns (uint32) {
    GovernorTwabVotesStorage storage $ = _getGovernorTwabVotesStorage();
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
    GovernorTwabVotesStorage storage $ = _getGovernorTwabVotesStorage();
    return $.token.getAccountTwabByTimestampRange(
      account, SafeCast.toUint48(timepoint - $.twabPeriod), SafeCast.toUint48(timepoint)
    );
  }

  function _getTotalVotingPower(uint256 timepoint) internal view virtual returns (uint256) {
    GovernorTwabVotesStorage storage $ = _getGovernorTwabVotesStorage();
    return
      $.token.getTotalTwabByTimestampRange(SafeCast.toUint48(timepoint - $.twabPeriod), SafeCast.toUint48(timepoint));
  }
}
