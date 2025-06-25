// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';
import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { MatrixVaultBasic } from '../../../src/hub/matrix/MatrixVaultBasic.sol';
import { MatrixVaultCapped } from '../../../src/hub/matrix/MatrixVaultCapped.sol';
import { MatrixVaultFactory } from '../../../src/hub/matrix/MatrixVaultFactory.sol';
import { IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IMatrixVaultFactory } from '../../../src/interfaces/hub/matrix/IMatrixVaultFactory.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MatrixVaultFactoryTest is Toolkit {
  address public owner = makeAddr('owner');
  MockContract public assetManager;
  MockContract public reclaimQueue;

  ERC1967Factory public proxyFactory;

  MatrixVaultBasic public basicImpl;
  MatrixVaultCapped public cappedImpl;
  MatrixVaultFactory public factoryImpl;

  MatrixVaultFactory public base;

  uint8 BasicVaultType = uint8(IMatrixVaultFactory.VaultType.Basic);
  uint8 CappedVaultType = uint8(IMatrixVaultFactory.VaultType.Capped);

  function setUp() public {
    assetManager = new MockContract();
    reclaimQueue = new MockContract();
    assetManager.setRet(
      abi.encodeCall(IAssetManagerStorageV1.reclaimQueue, ()), false, abi.encode(address(reclaimQueue))
    );

    proxyFactory = new ERC1967Factory();

    basicImpl = new MatrixVaultBasic();
    cappedImpl = new MatrixVaultCapped();
    factoryImpl = new MatrixVaultFactory();

    base = MatrixVaultFactory(
      payable(new ERC1967Proxy(address(factoryImpl), abi.encodeCall(MatrixVaultFactory.initialize, (owner))))
    );
  }

  function test_init() public view {
    assertEq(base.owner(), owner);
    assertEq(_erc1967Impl(address(base)), address(factoryImpl));
  }

  function test_initVaultType() public {
    vm.startPrank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));
    base.initVaultType(CappedVaultType, address(cappedImpl));
    vm.stopPrank();

    assertNotEq(base.beacon(BasicVaultType), address(0));
    assertNotEq(base.beacon(CappedVaultType), address(0));

    assertTrue(base.vaultTypeInitialized(BasicVaultType));
    assertTrue(base.vaultTypeInitialized(CappedVaultType));
  }

  function test_create_basic() public returns (address) {
    vm.prank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));

    address instance = _createBasic(owner, address(new WETH()), 'Basic Vault', 'BV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(BasicVaultType), _erc1967Beacon(instance));

    assertEq(base.instancesLength(BasicVaultType), 1);
    assertEq(base.instances(BasicVaultType, 0), instance);

    return instance;
  }

  function test_create_capped() public returns (address) {
    vm.prank(owner);
    base.initVaultType(CappedVaultType, address(cappedImpl));

    address instance = _createCapped(owner, address(new WETH()), 'Capped Vault', 'CV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(CappedVaultType), _erc1967Beacon(instance));

    assertEq(base.instancesLength(CappedVaultType), 1);
    assertEq(base.instances(CappedVaultType, 0), instance);

    return instance;
  }

  function test_migrate() public {
    vm.startPrank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));
    base.initVaultType(CappedVaultType, address(cappedImpl));
    vm.stopPrank();

    address basicI1 = _createBasic(owner, address(new WETH()), 'Basic Vault 1', 'BV1');
    address basicI2 = _createBasic(owner, address(new WETH()), 'Basic Vault 2', 'BV2');
    address cappedI1 = _createCapped(owner, address(new WETH()), 'Capped Vault 1', 'CV1');
    address cappedI2 = _createCapped(owner, address(new WETH()), 'Capped Vault 2', 'CV2');

    vm.prank(owner);
    base.migrate(BasicVaultType, CappedVaultType, basicI1, '');

    assertEq(base.instancesLength(BasicVaultType), 1);
    assertEq(base.instancesLength(CappedVaultType), 3);
    assertEq(base.instances(CappedVaultType, 0), cappedI1);
    assertEq(base.instances(CappedVaultType, 1), cappedI2);
    assertEq(base.instances(CappedVaultType, 2), basicI1);

    assertEq(base.beacon(CappedVaultType), _erc1967Beacon(basicI1));

    vm.prank(owner);
    base.migrate(CappedVaultType, BasicVaultType, basicI1, '');

    assertEq(base.instancesLength(BasicVaultType), 2);
    assertEq(base.instancesLength(CappedVaultType), 2);
    assertEq(base.instances(BasicVaultType, 0), basicI2);
    assertEq(base.instances(BasicVaultType, 1), basicI1);
    assertEq(base.instances(CappedVaultType, 0), cappedI1);
    assertEq(base.instances(CappedVaultType, 1), cappedI2);
  }

  function test_VaultType_cast() public {
    vm.startPrank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));
    base.initVaultType(CappedVaultType, address(cappedImpl));
    vm.stopPrank();

    uint8 maxVaultType = base.MAX_VAULT_TYPE();

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.beacon(maxVaultType + 1);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.isInstance(maxVaultType + 1, address(0));

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.instances(maxVaultType + 1, 0);

    uint256[] memory indexes;
    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.instances(maxVaultType + 1, indexes);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.instancesLength(maxVaultType + 1);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.vaultTypeInitialized(maxVaultType + 1);

    vm.startPrank(owner);

    bytes memory data;
    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.callBeacon(maxVaultType + 1, data);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.create(maxVaultType + 1, data);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.migrate(maxVaultType + 1, maxVaultType, address(0), data);

    vm.expectRevert(_errEnumOutOfBounds(maxVaultType, maxVaultType + 1));
    base.migrate(maxVaultType, maxVaultType + 1, address(0), data);

    vm.stopPrank();
  }

  function _createBasic(address caller, IMatrixVaultFactory.BasicVaultInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(BasicVaultType, abi.encode(args));
  }

  function _createBasic(address caller, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createBasic(
      caller,
      IMatrixVaultFactory.BasicVaultInitArgs({
        assetManager: address(assetManager),
        asset: IERC20Metadata(asset),
        name: name,
        symbol: symbol
      })
    );
  }

  function _createCapped(address caller, IMatrixVaultFactory.CappedVaultInitArgs memory args)
    internal
    returns (address)
  {
    vm.prank(caller);
    return base.create(CappedVaultType, abi.encode(args));
  }

  function _createCapped(address caller, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createCapped(
      caller,
      IMatrixVaultFactory.CappedVaultInitArgs({
        assetManager: address(assetManager),
        asset: IERC20Metadata(asset),
        name: name,
        symbol: symbol
      })
    );
  }
}
