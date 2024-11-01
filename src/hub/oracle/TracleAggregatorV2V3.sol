// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Initializable } from '@oz-v5/proxy/utils/Initializable.sol';

import { AggregatorV2V3Interface } from '../../interfaces/hub/oracle/AggregatorV2V3Interface.sol';
import { ITracle, TracleConstants } from '../../interfaces/hub/oracle/ITracle.sol';
import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';

/**
 * @title TracleAggregatorV2V3
 * @notice A chainlink-compatible aggregator contract powered by mitosis testnet oracle feeds.
 */
contract TracleAggregatorV2V3 is AggregatorV2V3Interface, Initializable {
  using ERC7201Utils for string;

  // =========================== NOTE: STORAGE DEFINITIONS =========================== //

  struct Storage {
    ITracle tracle;
    bytes32 priceId;
  }

  string private constant _NAMESPACE = 'mitosis.storage.TracleAggregatorV2V3';
  bytes32 private immutable _slot = _NAMESPACE.storageSlot();

  function _getStorage() internal view returns (Storage storage $) {
    bytes32 slot = _slot;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }

  // ============================ NOTE: INITIALIZATION FUNCTIONS ============================ //

  constructor() {
    _disableInitializers();
  }

  function initialize(ITracle tracle_, bytes32 priceId_) external initializer {
    Storage storage $ = _getStorage();
    $.tracle = tracle_;
    $.priceId = priceId_;
  }

  function tracle() external view returns (ITracle) {
    return _getStorage().tracle;
  }

  function priceId() external view returns (bytes32) {
    return _getStorage().priceId;
  }

  function decimals() external pure returns (uint8) {
    return TracleConstants.PRICE_DECIMALS;
  }

  function description() external pure returns (string memory) {
    return 'A port of a chainlink aggregator powered by mitosis testnet oracle feeds';
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() public view returns (int256) {
    Storage storage $ = _getStorage();
    ITracle.Price memory price = $.tracle.getPrice($.priceId);
    return int256(uint256(price.price));
  }

  function latestTimestamp() public view returns (uint256) {
    Storage storage $ = _getStorage();
    ITracle.Price memory price = $.tracle.getPrice($.priceId);
    return price.updatedAt;
  }

  function latestRound() external view returns (uint256) {
    // use timestamp as the round id
    return latestTimestamp();
  }

  function getAnswer(uint256) external view returns (int256) {
    return latestAnswer();
  }

  function getTimestamp(uint256) external view returns (uint256) {
    return latestTimestamp();
  }

  function getRoundData(uint80 _roundId)
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    Storage storage $ = _getStorage();
    ITracle.Price memory price = $.tracle.getPrice($.priceId);
    return (_roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, _roundId);
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    Storage storage $ = _getStorage();
    ITracle.Price memory price = $.tracle.getPrice($.priceId);
    roundId = uint80(price.updatedAt);
    return (roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, roundId);
  }
}
