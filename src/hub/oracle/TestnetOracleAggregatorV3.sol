// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AggregatorV3Interface } from '../../interfaces/hub/oracle/AggregatorV3Interface.sol';
import { ITestnetOracle, TestnetOracleConstants } from '../../interfaces/hub/oracle/ITestnetOracle.sol';

contract TestnetOracleAggregatorV3 is AggregatorV3Interface {
  ITestnetOracle private _oracle;
  bytes32 private _priceId;

  constructor(ITestnetOracle oracle_, bytes32 priceId_) {
    _oracle = oracle_;
    _priceId = priceId_;
  }

  function oracle() external view returns (ITestnetOracle) {
    return _oracle;
  }

  function priceId() external view returns (bytes32) {
    return _priceId;
  }

  function decimals() external view virtual returns (uint8) {
    return TestnetOracleConstants.PRICE_DECIMALS;
  }

  function description() external pure returns (string memory) {
    return 'A port of a chainlink aggregator powered by mitosis testnet oracle feeds';
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() public view virtual returns (int256) {
    ITestnetOracle.Price memory price = _oracle.getPrice(_priceId);
    return int256(uint256(price.price));
  }

  function latestTimestamp() public view returns (uint256) {
    ITestnetOracle.Price memory price = _oracle.getPrice(_priceId);
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
    ITestnetOracle.Price memory price = _oracle.getPrice(_priceId);
    return (_roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, _roundId);
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    ITestnetOracle.Price memory price = _oracle.getPrice(_priceId);
    roundId = uint80(price.updatedAt);
    return (roundId, int256(uint256(price.price)), price.updatedAt, price.updatedAt, roundId);
  }
}
