// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

contract BaseDecoderAndSanitizer {
  error BaseDecoderAndSanitizer__FunctionSelectorNotSupported();

  //============================== IMMUTABLES ===============================

  address internal immutable _strategyExecutor;

  constructor(address strategyExecutor_) {
    _strategyExecutor = strategyExecutor_;
  }

  function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(spender);
  }

  function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
    addressesFound = abi.encodePacked(_to);
  }

  //============================== FALLBACK ===============================
  /**
   * @notice The purpose of this function is to revert with a known error,
   *         so that during merkle tree creation we can verify that a
   *         leafs decoder and sanitizer implments the required function
   *         selector.
   */
  fallback() external {
    revert BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
  }
}
