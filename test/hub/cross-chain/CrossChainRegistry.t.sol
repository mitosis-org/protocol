// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Vm } from '@std/Vm.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { CrossChainRegistry } from '../../../src/hub/cross-chain/CrossChainRegistry.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract TestCrossChainRegistry is Toolkit {
  CrossChainRegistry internal ccRegistry;

  ProxyAdmin internal _proxyAdmin;

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);

    CrossChainRegistry ccRegistryImpl = new CrossChainRegistry();
    ccRegistry = CrossChainRegistry(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(ccRegistryImpl),
            address(_proxyAdmin),
            abi.encodeWithSelector(ccRegistry.initialize.selector, 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)
          )
        )
      )
    );
    ccRegistry.grantRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
  }

  function test_auth() public {
    ccRegistry.revokeRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);

    uint256 chainID = 1;
    string memory name = 'Ethereum';
    uint32 hplDomain = 1;
    address entrypoint = _addr('entrypoint');

    vm.expectRevert(); // 'AccessControlUnauthorizedAccount'
    ccRegistry.setChain(chainID, name, hplDomain, entrypoint);

    ccRegistry.grantRole(ccRegistry.REGISTERER_ROLE(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
    ccRegistry.setChain(chainID, name, hplDomain, entrypoint);
  }

  function test_setChain() public {
    uint256 chainID = 1;
    string memory name = 'Ethereum';
    uint32 hplDomain = 1;
    address entrypoint = _addr('entrypoint');

    ccRegistry.setChain(chainID, name, hplDomain, entrypoint);

    vm.expectRevert(); // 'already registered chain'
    ccRegistry.setChain(chainID, name, hplDomain, entrypoint);

    uint256[] memory chainIds = ccRegistry.chainIds();
    require(chainIds.length == 1, 'invalid chainIds');
    require(chainIds[0] == chainID, 'invalid chainIds');
    require(
      keccak256(abi.encodePacked(ccRegistry.chainName(1))) == keccak256(abi.encodePacked(name)), 'invalid chainNmae'
    );
    require(ccRegistry.hyperlaneDomain(chainID) == hplDomain, 'invalid hyperlaneDomain');
    require(ccRegistry.entrypoint(chainID) == entrypoint, 'invalid entrypoint');
    require(ccRegistry.chainId(hplDomain) == chainID, 'invalid chainId');
  }

  function test_setVault() public {
    uint256 chainID = 1;
    address vault = _addr('vault');
    address entrypoint = _addr('entrypoint');

    vm.expectRevert(); // 'not registered chain'
    ccRegistry.setVault(chainID, vault);

    string memory name = 'Ethereum';
    uint32 hplDomain = 1;
    ccRegistry.setChain(chainID, name, hplDomain, entrypoint);
    ccRegistry.setVault(chainID, vault);
    require(ccRegistry.vault(chainID) == vault, 'invalid vault');
  }
}
