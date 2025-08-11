// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';
import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { IERC20Metadata } from '@oz/interfaces/IERC20Metadata.sol';
import { ERC1967Proxy } from '@oz/proxy/ERC1967/ERC1967Proxy.sol';

import { VLFBasic } from '../../../src/hub/vlf/VLFBasic.sol';
import { VLFCapped } from '../../../src/hub/vlf/VLFCapped.sol';
import { VLFFactory } from '../../../src/hub/vlf/VLFFactory.sol';
import { IAssetManagerStorageV1 } from '../../../src/interfaces/hub/core/IAssetManager.sol';
import { IVLFFactory } from '../../../src/interfaces/hub/vlf/IVLFFactory.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract VLFFactoryTest is Toolkit {
  address public owner = makeAddr('owner');
  MockContract public assetManager;
  MockContract public reclaimQueue;

  ERC1967Factory public proxyFactory;

  VLFBasic public basicImpl;
  VLFCapped public cappedImpl;
  VLFFactory public factoryImpl;

  VLFFactory public base;

  uint8 BasicVLFType = uint8(IVLFFactory.VLFType.Basic);
  uint8 CappedVLFType = uint8(IVLFFactory.VLFType.Capped);

  function setUp() public {
    assetManager = new MockContract();
    reclaimQueue = new MockContract();
    assetManager.setRet(
      abi.encodeCall(IAssetManagerStorageV1.reclaimQueue, ()), false, abi.encode(address(reclaimQueue))
    );

    proxyFactory = new ERC1967Factory();

    basicImpl = new VLFBasic();
    cappedImpl = new VLFCapped();
    factoryImpl = new VLFFactory();

    base = VLFFactory(payable(new ERC1967Proxy(address(factoryImpl), abi.encodeCall(VLFFactory.initialize, (owner)))));
  }

  function test_init() public view {
    assertEq(base.owner(), owner);
    assertEq(_erc1967Impl(address(base)), address(factoryImpl));
  }

  function test_initVLFType() public {
    vm.startPrank(owner);
    base.initVLFType(BasicVLFType, address(basicImpl));
    base.initVLFType(CappedVLFType, address(cappedImpl));
    vm.stopPrank();

    assertNotEq(base.beacon(BasicVLFType), address(0));
    assertNotEq(base.beacon(CappedVLFType), address(0));

    assertTrue(base.vlfTypeInitialized(BasicVLFType));
    assertTrue(base.vlfTypeInitialized(CappedVLFType));
  }

  function test_create_basic() public returns (address) {
    vm.prank(owner);
    base.initVLFType(BasicVLFType, address(basicImpl));

    address instance = _createBasic(owner, address(new WETH()), 'Basic VLF', 'BV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(BasicVLFType), _erc1967Beacon(instance));

    assertEq(base.instancesLength(BasicVLFType), 1);
    assertEq(base.instances(BasicVLFType, 0), instance);

    return instance;
  }

  function test_create_capped() public returns (address) {
    vm.prank(owner);
    base.initVLFType(CappedVLFType, address(cappedImpl));

    address instance = _createCapped(owner, address(new WETH()), 'Capped VLF', 'CV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(CappedVLFType), _erc1967Beacon(instance));

    assertEq(base.instancesLength(CappedVLFType), 1);
    assertEq(base.instances(CappedVLFType, 0), instance);

    return instance;
  }

  function test_migrate() public {
    vm.startPrank(owner);
    base.initVLFType(BasicVLFType, address(basicImpl));
    base.initVLFType(CappedVLFType, address(cappedImpl));
    vm.stopPrank();

    address basicI1 = _createBasic(owner, address(new WETH()), 'Basic VLF 1', 'BV1');
    address basicI2 = _createBasic(owner, address(new WETH()), 'Basic VLF 2', 'BV2');
    address cappedI1 = _createCapped(owner, address(new WETH()), 'Capped VLF 1', 'CV1');
    address cappedI2 = _createCapped(owner, address(new WETH()), 'Capped VLF 2', 'CV2');

    vm.prank(owner);
    base.migrate(BasicVLFType, CappedVLFType, basicI1, '');

    assertEq(base.instancesLength(BasicVLFType), 1);
    assertEq(base.instancesLength(CappedVLFType), 3);
    assertEq(base.instances(CappedVLFType, 0), cappedI1);
    assertEq(base.instances(CappedVLFType, 1), cappedI2);
    assertEq(base.instances(CappedVLFType, 2), basicI1);

    assertEq(base.beacon(CappedVLFType), _erc1967Beacon(basicI1));

    vm.prank(owner);
    base.migrate(CappedVLFType, BasicVLFType, basicI1, '');

    assertEq(base.instancesLength(BasicVLFType), 2);
    assertEq(base.instancesLength(CappedVLFType), 2);
    assertEq(base.instances(BasicVLFType, 0), basicI2);
    assertEq(base.instances(BasicVLFType, 1), basicI1);
    assertEq(base.instances(CappedVLFType, 0), cappedI1);
    assertEq(base.instances(CappedVLFType, 1), cappedI2);
  }

  function test_VLFType_cast() public {
    vm.startPrank(owner);
    base.initVLFType(BasicVLFType, address(basicImpl));
    base.initVLFType(CappedVLFType, address(cappedImpl));
    vm.stopPrank();

    uint8 maxVLFType = base.MAX_VLF_TYPE();

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.beacon(maxVLFType + 1);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.isInstance(maxVLFType + 1, address(0));

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.instances(maxVLFType + 1, 0);

    uint256[] memory indexes;
    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.instances(maxVLFType + 1, indexes);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.instancesLength(maxVLFType + 1);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.vlfTypeInitialized(maxVLFType + 1);

    vm.startPrank(owner);

    bytes memory data;
    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.callBeacon(maxVLFType + 1, data);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.create(maxVLFType + 1, data);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.migrate(maxVLFType + 1, maxVLFType, address(0), data);

    vm.expectRevert(_errEnumOutOfBounds(maxVLFType, maxVLFType + 1));
    base.migrate(maxVLFType, maxVLFType + 1, address(0), data);

    vm.stopPrank();
  }

  function _createBasic(address caller, IVLFFactory.BasicVLFInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(BasicVLFType, abi.encode(args));
  }

  function _createBasic(address caller, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createBasic(
      caller,
      IVLFFactory.BasicVLFInitArgs({
        assetManager: address(assetManager),
        asset: IERC20Metadata(asset),
        name: name,
        symbol: symbol
      })
    );
  }

  function _createCapped(address caller, IVLFFactory.CappedVLFInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(CappedVLFType, abi.encode(args));
  }

  function _createCapped(address caller, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createCapped(
      caller,
      IVLFFactory.CappedVLFInitArgs({
        assetManager: address(assetManager),
        asset: IERC20Metadata(asset),
        name: name,
        symbol: symbol
      })
    );
  }
}
