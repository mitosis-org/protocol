// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/// @dev placeholder for future definitions
enum EOLAction {
  None
}

interface IMitosisVaultEOL {
  //=========== NOTE: EVENT DEFINITIONS ===========//

  event EOLInitialized(address hubEOLVault, address asset);
  event EOLDepositedWithSupply(address indexed asset, address indexed to, address indexed hubEOLVault, uint256 amount);

  event EOLHalted(address indexed hubEOLVault, EOLAction action);
  event EOLResumed(address indexed hubEOLVault, EOLAction action);

  //=========== NOTE: ERROR DEFINITIONS ===========//

  error IMitosisVaultEOL__EOLNotInitialized(address hubEOLVault);
  error IMitosisVaultEOL__EOLAlreadyInitialized(address hubEOLVault);
  error IMitosisVaultEOL__InvalidEOLVault(address hubEOLVault, address asset);

  //=========== NOTE: View functions ===========//

  function isEOLInitialized(address hubEOLVault) external view returns (bool);

  function quoteDepositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount)
    external
    view
    returns (uint256);

  //=========== NOTE: Asset ===========//

  function depositWithSupplyEOL(address asset, address to, address hubEOLVault, uint256 amount) external payable;

  //=========== NOTE: OWNABLE FUNCTIONS ===========//

  function initializeEOL(address hubEOLVault, address asset) external;
}
