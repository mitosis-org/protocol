// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';
import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { EOLVault } from '../../../src/hub/eol/EOLVault.sol';
import { EOLVaultFactory } from '../../../src/hub/eol/EOLVaultFactory.sol';
import { IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IEOLVaultFactory } from '../../../src/interfaces/hub/eol/IEOLVaultFactory.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EOLVaultFactoryTest is Toolkit {
  address public owner = makeAddr('owner');

  ERC1967Factory public proxyFactory;

  EOLVault public basicImpl;
  EOLVaultFactory public base;

  function setUp() public {
    proxyFactory = new ERC1967Factory();

    basicImpl = new EOLVault();

    base = EOLVaultFactory(
      payable(new ERC1967Proxy(address(new EOLVaultFactory()), abi.encodeCall(EOLVaultFactory.initialize, (owner))))
    );
  }

  function test_init() public view {
    assertEq(base.owner(), owner);
  }

  function test_initVaultType() public {
    vm.startPrank(owner);
    base.initVaultType(IEOLVaultFactory.VaultType.Basic, address(basicImpl));
    vm.stopPrank();

    assertNotEq(base.beacon(IEOLVaultFactory.VaultType.Basic), address(0));

    assertTrue(base.vaultTypeInitialized(IEOLVaultFactory.VaultType.Basic));
  }

  function test_create_basic() public returns (address) {
    vm.prank(owner);
    base.initVaultType(IEOLVaultFactory.VaultType.Basic, address(basicImpl));

    address instance = _createBasic(owner, owner, address(new WETH()), 'Basic Vault', 'BV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(IEOLVaultFactory.VaultType.Basic), _erc1967Beacon(instance));

    assertEq(base.instancesLength(IEOLVaultFactory.VaultType.Basic), 1);
    assertEq(base.instances(IEOLVaultFactory.VaultType.Basic, 0), instance);

    return instance;
  }

  // function test_migrate() public {
  //   vm.prank(owner);
  //   base.initVaultType(IEOLVaultFactory.VaultType.Basic, address(basicImpl));

  //   address instance1 = _createBasic(owner, owner, address(new WETH()), 'Basic Vault 1', 'BV1');
  //   address instance2 = _createBasic(owner, owner, address(new WETH()), 'Basic Vault 2', 'BV2');
  //   address instance3 = _createBasic(owner, owner, address(new WETH()), 'Basic Vault 3', 'BV3');

  //   vm.prank(owner);
  //   base.migrate(IEOLVaultFactory.VaultType.Basic, IEOLVaultFactory.VaultType.Basic, instance1, '');
  // }

  function _createBasic(address caller, IEOLVaultFactory.BasicVaultInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(IEOLVaultFactory.VaultType.Basic, abi.encode(args));
  }

  function _createBasic(address caller, address owner_, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createBasic(
      caller,
      IEOLVaultFactory.BasicVaultInitArgs({ owner: owner_, asset: IERC20Metadata(asset), name: name, symbol: symbol })
    );
  }
}
