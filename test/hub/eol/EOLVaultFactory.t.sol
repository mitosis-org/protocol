// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { WETH } from '@solady/tokens/WETH.sol';
import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';
import { UpgradeableBeacon } from '@solady/utils/UpgradeableBeacon.sol';

import { Ownable } from '@oz/access/Ownable.sol';
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
  address assetManager = _emptyContract();
  address reclaimQueue = _emptyContract();

  ERC1967Factory public proxyFactory;

  EOLVault public basicImpl;
  EOLVaultFactory public base;

  uint8 BasicVaultType = uint8(IEOLVaultFactory.VaultType.Basic);

  function setUp() public {
    proxyFactory = new ERC1967Factory();

    basicImpl = new EOLVault();

    vm.mockCall(
      address(assetManager),
      abi.encodeWithSelector(IAssetManagerStorageV1.reclaimQueue.selector),
      abi.encode(reclaimQueue)
    );

    vm.mockCall(address(assetManager), abi.encodeWithSelector(Ownable.owner.selector), abi.encode(owner));

    base = EOLVaultFactory(
      payable(new ERC1967Proxy(address(new EOLVaultFactory()), abi.encodeCall(EOLVaultFactory.initialize, (owner))))
    );
  }

  function test_init() public view {
    assertEq(base.owner(), owner);
  }

  function test_initVaultType() public {
    vm.startPrank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));
    vm.stopPrank();

    assertNotEq(base.beacon(BasicVaultType), address(0));

    assertTrue(base.vaultTypeInitialized(BasicVaultType));
  }

  function test_create_basic() public returns (address) {
    vm.prank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));

    address instance = _createBasic(owner, assetManager, address(new WETH()), 'Basic Vault', 'BV');

    assertEq(address(0x0), _erc1967Admin(instance));
    assertEq(address(0x0), _erc1967Impl(instance));
    assertEq(base.beacon(BasicVaultType), _erc1967Beacon(instance));

    assertEq(base.instancesLength(BasicVaultType), 1);
    assertEq(base.instances(BasicVaultType, 0), instance);

    return instance;
  }

  function test_VaultType_cast() public {
    vm.startPrank(owner);
    base.initVaultType(BasicVaultType, address(basicImpl));
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

  // function test_migrate() public {
  //   vm.prank(owner);
  //   base.initVaultType(BasicVaultType, address(basicImpl));

  //   address instance1 = _createBasic(owner, assetManager, address(new WETH()), 'Basic Vault 1', 'BV1');
  //   address instance2 = _createBasic(owner, assetManager, address(new WETH()), 'Basic Vault 2', 'BV2');
  //   address instance3 = _createBasic(owner, assetManager, address(new WETH()), 'Basic Vault 3', 'BV3');

  //   vm.prank(owner);
  //   base.migrate(BasicVaultType, BasicVaultType, instance1, '');
  // }

  function _createBasic(address caller, IEOLVaultFactory.BasicVaultInitArgs memory args) internal returns (address) {
    vm.prank(caller);
    return base.create(BasicVaultType, abi.encode(args));
  }

  function _createBasic(address caller, address assetManager_, address asset, string memory name, string memory symbol)
    internal
    returns (address)
  {
    return _createBasic(
      caller,
      IEOLVaultFactory.BasicVaultInitArgs({
        assetManager: assetManager_,
        asset: IERC20Metadata(asset),
        name: name,
        symbol: symbol
      })
    );
  }
}
