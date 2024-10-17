// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { EOLProtocolRegistry } from '../../../src/hub/eol/EOLProtocolRegistry.sol';
import { IEOLProtocolRegistry } from '../../../src/interfaces/hub/eol/IEOLProtocolRegistry.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EOLProtocolRegistryTest is Toolkit {
  EOLProtocolRegistry _eolProtocolRegistry;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');

  address immutable eolAsset = makeAddr('eolAsset');
  uint256 immutable chainId = 65310;

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    EOLProtocolRegistry eolProtocolRegistryImpl = new EOLProtocolRegistry();
    _eolProtocolRegistry = EOLProtocolRegistry(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolProtocolRegistryImpl),
            address(_proxyAdmin),
            abi.encodeCall(_eolProtocolRegistry.initialize, (owner))
          )
        )
      )
    );
  }

  function test_registerProtocol() public {
    vm.prank(owner);
    _eolProtocolRegistry.authorize(eolAsset, address(owner));

    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(protocolId));

    vm.prank(owner);
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, 'Test', makeAddr('branchStrategy'), 'For testing');

    assertTrue(_eolProtocolRegistry.isProtocolRegistered(protocolId));
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test'));
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'test'));

    uint256[] memory protocolIds = _eolProtocolRegistry.protocolIds(eolAsset, chainId);
    assertEq(protocolIds.length, 1);
    assertEq(protocolIds[0], protocolId);
  }

  function test_registerProtocol_protocolIds() public {
    vm.prank(owner);
    _eolProtocolRegistry.authorize(eolAsset, address(owner));

    uint256 protocolId1 = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test_1');
    uint256 protocolId2 = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test_2');
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(protocolId1));
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(protocolId2));

    vm.startPrank(owner);
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, 'Test_1', makeAddr('branchStrategy'), 'For testing');
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, 'Test_2', makeAddr('branchStrategy'), 'For testing');
    vm.stopPrank();

    assertTrue(_eolProtocolRegistry.isProtocolRegistered(protocolId1));
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(protocolId2));
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test_1'));
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'test_2'));

    uint256[] memory protocolIds = _eolProtocolRegistry.protocolIds(eolAsset, chainId);
    assertEq(protocolIds.length, 2);
    assertEq(protocolIds[0], protocolId1);
    assertEq(protocolIds[1], protocolId2);
  }

  function test_registerProtocol_Unauthorized() public {
    vm.prank(owner);
    _eolProtocolRegistry.authorize(eolAsset, address(owner));

    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(protocolId));

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, 'Test', makeAddr('branchStrategy'), 'For testing');
  }

  function test_registerProtocol_InvalidParameter() public {
    vm.prank(owner);
    _eolProtocolRegistry.authorize(eolAsset, address(owner));

    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');
    assertFalse(_eolProtocolRegistry.isProtocolRegistered(protocolId));

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('name'));
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, '', makeAddr('branchStrategy'), 'For testing');

    vm.stopPrank();
  }

  function test_registerProtocol_AlreadyRegistered() public {
    test_registerProtocol();
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test'));

    vm.startPrank(owner);

    vm.expectRevert(
      _errAlreadyRegistered(_eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test'), eolAsset, chainId, 'Test')
    );
    _eolProtocolRegistry.registerProtocol(eolAsset, chainId, 'Test', makeAddr('branchStrategy'), 'For testing');

    vm.stopPrank();
  }

  function test_unregisterProtocol() public {
    test_registerProtocol();
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test'));

    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');

    vm.prank(owner);
    _eolProtocolRegistry.unregisterProtocol(protocolId);

    assertFalse(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test'));
  }

  function test_unregisterProtocol_Unauthorized() public {
    test_registerProtocol();
    assertTrue(_eolProtocolRegistry.isProtocolRegistered(eolAsset, chainId, 'Test'));

    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolProtocolRegistry.unregisterProtocol(protocolId);
  }

  function test_unregisterProtocol_NotRegistered() public {
    uint256 protocolId = _eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test');

    vm.startPrank(owner);

    vm.expectRevert(_errNotRegistered(protocolId));
    _eolProtocolRegistry.unregisterProtocol(protocolId);
    vm.stopPrank();
  }

  function test_protocolId() public view {
    bytes32 nameHash = keccak256(bytes('Test'));
    uint256 expect = uint256(keccak256(abi.encode(eolAsset, chainId, nameHash)));
    assertEq(_eolProtocolRegistry.protocolId(eolAsset, chainId, 'Test'), expect);
  }

  function _errAlreadyRegistered(uint256 protocolId, address eolAsset_, uint256 chainId_, string memory name)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      IEOLProtocolRegistry.IEOLProtocolRegistry__AlreadyRegistered.selector, protocolId, eolAsset_, chainId_, name
    );
  }

  function _errNotRegistered(uint256 protocolId) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IEOLProtocolRegistry.IEOLProtocolRegistry__NotRegistered.selector, protocolId);
  }
}
