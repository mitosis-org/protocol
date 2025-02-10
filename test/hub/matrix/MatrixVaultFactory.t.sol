// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';
import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';
import { IERC20Metadata } from '@oz-v5/interfaces/IERC20Metadata.sol';

import { MatrixVaultFactory } from '../../../src/hub/matrix/MatrixVaultFactory.sol';
import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { MatrixVaultCapped } from '../../../src/hub/matrix/MatrixVaultCapped.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract Empty { }

contract MatrixVaultFactoryTest is Toolkit {
  address public proxyAdmin = makeAddr('proxyAdmin');
  address public contractOwner = makeAddr('owner');
  address public supplyManager = address(new Empty());

  ERC1967Factory public proxyFactory;

  MatrixVaultBasic public basicImpl;
  MatrixVaultCapped public cappedImpl;
  MatrixVaultFactory public factoryImpl;
  MatrixVaultFactory public base;

  function setUp() public {
    proxyFactory = new ERC1967Factory();

    basicImpl = new MatrixVaultBasic();
    cappedImpl = new MatrixVaultCapped();
    factoryImpl = new MatrixVaultFactory();

    base = MatrixVaultFactory(
      proxyFactory.deployAndCall(
        address(factoryImpl), proxyAdmin, abi.encodeCall(MatrixVaultFactory.initialize, (contractOwner))
      )
    );
  }

  function test_init() public view {
    assertEq(base.owner(), contractOwner);
  }

  function test_initVaultType() public {
    vm.startPrank(contractOwner);
    base.initVaultType(MatrixVaultFactory.VaultType.Basic, address(basicImpl));
    base.initVaultType(MatrixVaultFactory.VaultType.Capped, address(cappedImpl));
    vm.stopPrank();

    assertNotEq(base.beacon(MatrixVaultFactory.VaultType.Basic), address(0));
    assertNotEq(base.beacon(MatrixVaultFactory.VaultType.Capped), address(0));

    assertTrue(base.vaultTypeInitialized(MatrixVaultFactory.VaultType.Basic));
    assertTrue(base.vaultTypeInitialized(MatrixVaultFactory.VaultType.Capped));
  }

  function test_create_basic() public returns (address) {
    vm.prank(contractOwner);
    base.initVaultType(MatrixVaultFactory.VaultType.Basic, address(basicImpl));

    address instance = _createBasic(
      contractOwner,
      MatrixVaultFactory.BasicVaultInitArgs({
        supplyManager: supplyManager,
        asset: IERC20Metadata(address(new WETH())),
        name: 'Basic Vault',
        symbol: 'BV'
      })
    );

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(MatrixVaultFactory.VaultType.Basic), _erc1967Beacon(instance));

    assertEq(base.instancesLength(MatrixVaultFactory.VaultType.Basic), 1);
    assertEq(base.instances(MatrixVaultFactory.VaultType.Basic, 0), instance);

    return instance;
  }

  function test_create_capped() public returns (address) {
    vm.prank(contractOwner);
    base.initVaultType(MatrixVaultFactory.VaultType.Capped, address(cappedImpl));

    address instance = _createCapped(
      contractOwner,
      MatrixVaultFactory.CappedVaultInitArgs({
        supplyManager: supplyManager,
        asset: IERC20Metadata(address(new WETH())),
        name: 'Capped Vault',
        symbol: 'CV'
      })
    );

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(MatrixVaultFactory.VaultType.Capped), _erc1967Beacon(instance));

    assertEq(base.instancesLength(MatrixVaultFactory.VaultType.Capped), 1);
    assertEq(base.instances(MatrixVaultFactory.VaultType.Capped, 0), instance);

    return instance;
  }

  function test_migrate() public {
    address basic = test_create_basic();
    address capped = test_create_capped();

    vm.prank(contractOwner);
    base.migrate(MatrixVaultFactory.VaultType.Basic, MatrixVaultFactory.VaultType.Capped, basic, '');

    assertEq(base.instancesLength(MatrixVaultFactory.VaultType.Basic), 0);
    assertEq(base.instancesLength(MatrixVaultFactory.VaultType.Capped), 2);
    assertEq(base.instances(MatrixVaultFactory.VaultType.Capped, 0), capped);
    assertEq(base.instances(MatrixVaultFactory.VaultType.Capped, 1), basic);

    assertEq(base.beacon(MatrixVaultFactory.VaultType.Capped), _erc1967Beacon(basic));
  }

  function _createBasic(address caller, MatrixVaultFactory.BasicVaultInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(MatrixVaultFactory.VaultType.Basic, abi.encode(args));
  }

  function _createCapped(address caller, MatrixVaultFactory.CappedVaultInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(MatrixVaultFactory.VaultType.Capped, abi.encode(args));
  }
}
