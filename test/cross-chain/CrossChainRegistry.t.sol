// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';

import { CrossChainRegistry } from '../../src/hub/cross-chain/CrossChainRegistry.sol';
import { MsgType } from '../../src/hub/cross-chain/messages/Message.sol';

contract TestCrossChainRegistry is Test {
  CrossChainRegistry internal ccRegistry;

  function setUp() public {
    ccRegistry = new CrossChainRegistry();
    ccRegistry.initialize(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
    ccRegistry.grantRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
  }

  function test_auth() public {
    ccRegistry.revokeRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);

    uint256 chainID = 1;
    string memory name = 'Ethereum';
    uint32 hplDomain = 1;

    vm.expectRevert(); // 'AccessControlUnauthorizedAccount'
    ccRegistry.setChain(chainID, name, hplDomain);

    ccRegistry.grantRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
    ccRegistry.setChain(chainID, name, hplDomain);
  }

  function test_setChain() public {
    uint256 chainID = 1;
    string memory name = 'Ethereum';
    uint32 hplDomain = 1;

    ccRegistry.setChain(chainID, name, hplDomain);

    vm.expectRevert(); // 'already registered chain'
    ccRegistry.setChain(chainID, name, hplDomain);

    uint256[] memory chainIds = ccRegistry.getChainIds();
    require(chainIds.length == 1, 'invalid getChainIds');
    require(chainIds[0] == chainID, 'invalid getChainIds');
    require(
      keccak256(abi.encodePacked(ccRegistry.getChainName(1))) == keccak256(abi.encodePacked(name)),
      'invalid getChainNmae'
    );
    require(ccRegistry.getHyperlaneDomain(chainID) == hplDomain, 'invalid getHyperlaneDomain');
    require(ccRegistry.getChainIdByHyperlaneDomain(hplDomain) == chainID, 'invalid getChainIdByHyperlaneDomain');
  }

  function test_setVault() public {
    uint256 chainID = 1;
    address vault = address(1);
    address underlyingAsset = address(2);

    vm.expectRevert(); // 'not registered chain'
    ccRegistry.setVault(chainID, vault, underlyingAsset);

    string memory name = 'Ethereum';
    uint32 hplDomain = 1;
    ccRegistry.setChain(chainID, name, hplDomain);

    ccRegistry.setVault(chainID, vault, underlyingAsset);
    require(ccRegistry.getVault(chainID, underlyingAsset) == vault, 'invalid getVault');
    require(ccRegistry.getVaultUnderlyingAsset(chainID, vault) == underlyingAsset, 'invalid getVault');
  }
}
