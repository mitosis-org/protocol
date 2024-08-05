// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from '@std/Vm.sol';
import { Test } from '@std/Test.sol';
import { console } from '@std/console.sol';

import { Storage } from '../../src/lib/Storage.sol';
import { CrossChainRegistry } from '../../src/cross-chain/CrossChainRegistry.sol';
import { MsgType } from '../../src/cross-chain/messages/Message.sol';

contract TestCrossChainRegistry is Test {
  CrossChainRegistry internal ccRegistry;

  function setUp() public {
    Storage strg = new Storage();
    ccRegistry = new CrossChainRegistry(address(strg));
    ccRegistry.grantWriter(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
  }

  function test_setChain() public {
    uint256 chainID = 1;
    string memory name = 'Ethereum';
    uint32 hplDomain = 1;

    ccRegistry.setChain(chainID, name, hplDomain);

    vm.expectRevert(); // 'already registered chain'
    ccRegistry.setChain(chainID, name, hplDomain);

    uint256[] memory chains = ccRegistry.getChains();
    require(chains.length == 1, 'invalid getChains');
    require(chains[0] == chainID, 'invalid getChains');
    require(
      keccak256(abi.encodePacked(ccRegistry.getChainName(1))) == keccak256(abi.encodePacked(name)),
      'invalid getChainNmae'
    );
    require(ccRegistry.getHyperlaneDomain(chainID) == hplDomain, 'invalid getHyperlaneDomain');
    require(ccRegistry.getChainByHyperlaneDomain(hplDomain) == chainID, 'invalid getChainByHyperlaneDomain');
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

  function test_setHyperlaneRoute() public {
    uint256 chainID = 1;
    uint32 hplDomain = 1;
    address msgDepositDestination = address(1);

    vm.expectRevert(); // 'not registered chain'
    ccRegistry.setHyperlaneRoute(hplDomain, MsgType.MsgDeposit, msgDepositDestination);

    string memory name = 'Ethereum';
    ccRegistry.setChain(chainID, name, hplDomain);

    ccRegistry.setHyperlaneRoute(hplDomain, MsgType.MsgDeposit, msgDepositDestination);
    require(
      ccRegistry.getHyperlaneRoute(hplDomain, MsgType.MsgDeposit) == msgDepositDestination, 'invalid getHyperlaneRoute'
    );
  }
}
