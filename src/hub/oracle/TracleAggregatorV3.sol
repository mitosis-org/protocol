// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from '../../interfaces/hub/oracle/AggregatorV3Interface.sol';
import { ITracle, TracleConstants } from '../../interfaces/hub/oracle/ITracle.sol';

/**
 * @title TracleAggregatorV3
 * @notice A chainlink-compatible aggregator contract powered by mitosis testnet oracle feeds.
 */
contract TracleAggregatorV3 is AggregatorV3Interface {
  ITracle private immutable _tracle;
  bytes32 private immutable _priceId;

  constructor(ITracle tracle_, bytes32 priceId_) {
    _tracle = tracle_;
    _priceId = priceId_;
  }

  function tracle() external view returns (ITracle) {
    return _tracle;
  }

  function priceId() external view returns (bytes32) {
    return _priceId;
  }

  function decimals() external view virtual returns (uint8) {
    return TracleConstants.PRICE_DECIMALS;
  }

  function description() external pure returns (string memory) {
    return 'A port of a chainlink aggregator powered by mitosis testnet oracle feeds';
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() public view virtual returns (int256) {
    ITracle.Price memory price = _tracle.getPrice(_priceId);
    return int256(uint256(price.price));
  }

  function latestTimestamp() public view returns (uint256) {
    ITracle.Price memory price = _tracle.getPrice(_priceId);
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
    ITracle.Price memory price = _tracle.getPrice(_priceId);
    return (_roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, _roundId);
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    ITracle.Price memory price = _tracle.getPrice(_priceId);
    roundId = uint80(price.updatedAt);
    return (roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, roundId);
  }
}
