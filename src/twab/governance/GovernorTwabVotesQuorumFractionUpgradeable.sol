// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/extensions/GovernorVotesQuorumFraction.sol)
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Checkpoints } from '@oz-v5/utils/structs/Checkpoints.sol';

import { Initializable } from '@ozu-v5/proxy/utils/Initializable.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { GovernorTwabVotesUpgradeable } from './GovernorTwabVotesUpgradeable.sol';
import { TwabSnapshotsUtils } from '../../lib/TwabSnapshotsUtils.sol';

// Modified to work with {ITwabSnapshots}.

pragma solidity ^0.8.26;

/**
 * @dev Extension of {Governor} for voting weight extraction from an {ITwabSnapshots} token and a quorum expressed as a
 * fraction of the total supply.
 */
abstract contract GovernorTwabVotesQuorumFractionUpgradeable is Initializable, GovernorTwabVotesUpgradeable {
  using ERC7201Utils for string;
  using Checkpoints for Checkpoints.Trace208;

  struct GovernorTwabVotesQuorumFractionStorage {
    Checkpoints.Trace208 _quorumNumeratorHistory;
  }

  string constant _GovernorTwabVotesQuorumFractionStorageNamespace = 'mitosis.storage.GovernorTwabVotesQuorumFraction';
  bytes32 private immutable _GovernorTwabVotesQuorumFractionStorageLocation =
    _GovernorTwabVotesQuorumFractionStorageNamespace.storageSlot();

  function _getGovernorTwabVotesQuorumFractionStorage()
    private
    view
    returns (GovernorTwabVotesQuorumFractionStorage storage $)
  {
    bytes32 slot = _GovernorTwabVotesQuorumFractionStorageLocation;
    assembly {
      $.slot := slot
    }
  }

  event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

  /**
   * @dev The quorum set is not a valid fraction.
   */
  error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);

  /**
   * @dev Initialize quorum as a fraction of the token's total supply.
   *
   * The fraction is specified as `numerator / denominator`. By default the denominator is 100, so quorum is
   * specified as a percent: a numerator of 10 corresponds to quorum being 10% of total supply. The denominator can be
   * customized by overriding {quorumDenominator}.
   */
  function __GovernorTwabVotesQuorumFraction_init(uint256 quorumNumeratorValue) internal onlyInitializing {
    __GovernorTwabVotesQuorumFraction_init_unchained(quorumNumeratorValue);
  }

  function __GovernorTwabVotesQuorumFraction_init_unchained(uint256 quorumNumeratorValue) internal onlyInitializing {
    _updateQuorumNumerator(quorumNumeratorValue);
  }

  /**
   * @dev Returns the current quorum numerator. See {quorumDenominator}.
   */
  function quorumNumerator() public view virtual returns (uint256) {
    GovernorTwabVotesQuorumFractionStorage storage $ = _getGovernorTwabVotesQuorumFractionStorage();
    return $._quorumNumeratorHistory.latest();
  }

  /**
   * @dev Returns the quorum numerator at a specific timepoint. See {quorumDenominator}.
   */
  function quorumNumerator(uint256 timepoint) public view virtual returns (uint256) {
    GovernorTwabVotesQuorumFractionStorage storage $ = _getGovernorTwabVotesQuorumFractionStorage();
    uint256 length = $._quorumNumeratorHistory._checkpoints.length;

    // Optimistic search, check the latest checkpoint
    Checkpoints.Checkpoint208 storage latest = $._quorumNumeratorHistory._checkpoints[length - 1];
    uint48 latestKey = latest._key;
    uint208 latestValue = latest._value;
    if (latestKey <= timepoint) {
      return latestValue;
    }

    // Otherwise, do the binary search
    return $._quorumNumeratorHistory.upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  /**
   * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
   */
  function quorumDenominator() public view virtual returns (uint256) {
    return 100;
  }

  /**
   * @dev Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
   */
  function quorum(uint256 timepoint) public view virtual override returns (uint256) {
    return (_getTotalVotingPower(timepoint) * quorumNumerator(timepoint)) / quorumDenominator();
  }

  /**
   * @dev Changes the quorum numerator.
   *
   * Emits a {QuorumNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - Must be called through a governance proposal.
   * - New numerator must be smaller or equal to the denominator.
   */
  function updateQuorumNumerator(uint256 newQuorumNumerator) external virtual onlyGovernance {
    _updateQuorumNumerator(newQuorumNumerator);
  }

  /**
   * @dev Changes the quorum numerator.
   *
   * Emits a {QuorumNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - New numerator must be smaller or equal to the denominator.
   */
  function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual {
    GovernorTwabVotesQuorumFractionStorage storage $ = _getGovernorTwabVotesQuorumFractionStorage();
    uint256 denominator = quorumDenominator();
    if (newQuorumNumerator > denominator) {
      revert GovernorInvalidQuorumFraction(newQuorumNumerator, denominator);
    }

    uint256 oldQuorumNumerator = quorumNumerator();
    $._quorumNumeratorHistory.push(clock(), SafeCast.toUint208(newQuorumNumerator));

    emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
  }
}
