// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MitosisVault, AssetAction, MatrixAction } from '../../../../src/branch/MitosisVault.sol';
import { ManagerWithMerkleVerification } from
  '../../../../src/branch/strategy/manager/ManagerWithMerkleVerification.sol';
import { MatrixStrategyExecutor } from '../../../../src/branch/strategy/MatrixStrategyExecutor.sol';
import { IMitosisVault, IMatrixMitosisVault } from '../../../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IManagerWithMerkleVerification } from
  '../../../../src/interfaces/branch/strategy/manager/IManagerWithMerkleVerification.sol';
import { StdError } from '../../../../src/lib/StdError.sol';
import { MockERC20Snapshots } from '../../../mock/MockERC20Snapshots.t.sol';
import { MockStrategyExecutor } from '../../../mock/MockStrategyExecutor.t.sol';
import { MockTestVault } from '../../../mock/MockTestVault.t.sol';
import { MockTestVaultDecoderAndSanitizer } from '../../../mock/MockTestVaultDecoderAndSanitizer.t.sol';
import { MockTestVaultTally } from '../../../mock/MockTestVaultTally.t.sol';
import { MerkleTreeHelper } from '../../../util/MerkleTreeHelper.sol';
import { Toolkit } from '../../../util/Toolkit.sol';

struct ManageLeaf {
  address target;
  bool canSendValue;
  string signature;
  address[] argumentAddresses;
  string description;
  address decoderAndSanitizer;
}

contract ManagerWithMerkleVerificationTest is Toolkit, MerkleTreeHelper {
  MockStrategyExecutor _strategyExecutor;
  ManagerWithMerkleVerification _managerWithMerkleVerification;
  ProxyAdmin _proxyAdmin;
  MockERC20Snapshots _token;
  MockTestVault _testVault;
  MockTestVaultDecoderAndSanitizer _testVaultDecoderAndSanitizer;
  MockTestVaultTally _testVaultTally;

  address immutable owner = makeAddr('owner');
  address immutable hubMatrixVault = makeAddr('hubMatrixVault');
  address immutable strategist = makeAddr('strategist');

  address immutable user1 = makeAddr('user1');
  address immutable user2 = makeAddr('user2');
  address immutable user3 = makeAddr('user3');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    _token = new MockERC20Snapshots();
    _token.initialize('Token', 'TKN');

    _strategyExecutor = new MockStrategyExecutor();

    ManagerWithMerkleVerification managerWithMerkleVerificationImpl =
      new ManagerWithMerkleVerification(address(_strategyExecutor));
    _managerWithMerkleVerification = ManagerWithMerkleVerification(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(managerWithMerkleVerificationImpl),
            address(_proxyAdmin),
            abi.encodeCall(managerWithMerkleVerificationImpl.initialize, (owner))
          )
        )
      )
    );

    _testVault = new MockTestVault(address(_token));
    _testVaultDecoderAndSanitizer = new MockTestVaultDecoderAndSanitizer(address(_strategyExecutor));

    vm.startPrank(owner);
    // note(ray): See the `test_generate_merkle_root` in this file.
    _managerWithMerkleVerification.setManageRoot(
      strategist, 0xc07180f6901e597e364bf4c873f952084261ba4d1c2fb40de8ffe98a3cc02030
    );
    vm.stopPrank();
  }

  function test_manageVaultWithMerkleVerification() public {
    bytes32[][] memory manageProofs;
    address[] memory decodersAndSanitizers;
    address[] memory targets;
    bytes[] memory targetData;
    uint256[] memory values;

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser2(100 ether);

    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser3(100 ether);

    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );
  }

  function test_manageVaultWithMerkleVerification_NotFound() public {
    bytes32[][] memory manageProofs;
    address[] memory decodersAndSanitizers;
    address[] memory targets;
    bytes[] memory targetData;
    uint256[] memory values;

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    vm.expectRevert(_errNotFound('manageProof'));
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );
  }

  function test_manageVaultWithMerkleVerification_FailedToVerifyManageProof() public {
    bytes32[][] memory manageProofs;
    address[] memory decodersAndSanitizers;
    address[] memory targets;
    bytes[] memory targetData;
    uint256[] memory values;

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    // invalid manageProofs
    manageProofs = new bytes32[][](1);
    manageProofs[0] = new bytes32[](3);
    manageProofs[0][0] = 0xa23e194a1cf74afb8fe2f73c879355502cd65f582b83a0f676e29c64653aeace;
    manageProofs[0][1] = 0x687c09d0be127ad293ecca1322a0a6e9bfc6808aaf924c3bd3ee003c6ab190d6;
    manageProofs[0][2] = 0;

    vm.expectRevert(_errFailedToVerifyManageProof(targets[0], targetData[0], values[0]));
    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    // invalid target address
    targets[0] = user2;

    vm.expectRevert(_errFailedToVerifyManageProof(targets[0], targetData[0], values[0]));
    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    // invalid decoderAndSanitizer address

    // AddressEmptyCode()
    decodersAndSanitizers[0] = address(0);

    vm.expectRevert();
    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    // FailedCAll()
    decodersAndSanitizers[0] = address(_token);
    vm.expectRevert();
    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );

    (manageProofs, decodersAndSanitizers, targets, targetData, values) = _makeManageParamterForUser1(100 ether);

    // invalid values (canSendValue)
    values[0] = 1 ether;

    vm.expectRevert(); // TODO
    vm.prank(strategist);
    _managerWithMerkleVerification.manageVaultWithMerkleVerification(
      manageProofs, decodersAndSanitizers, targets, targetData, values
    );
  }

  function test_setManageRoot() public {
    bytes32 root = 0x0000000000000000000000000000000000000000000000000000000000000001;
    address strategist2 = makeAddr('strategist2');

    vm.prank(owner);
    _managerWithMerkleVerification.setManageRoot(strategist2, root);

    assertEq(_managerWithMerkleVerification.manageRoot(strategist2), root);

    root = 0x0000000000000000000000000000000000000000000000000000000000000002;
    vm.prank(owner);
    _managerWithMerkleVerification.setManageRoot(strategist2, root);

    assertEq(_managerWithMerkleVerification.manageRoot(strategist2), root);
  }

  function test_setManageRoot_OwnableUnauthorizedAccount() public {
    bytes32 root = 0x0000000000000000000000000000000000000000000000000000000000000001;
    address strategist2 = makeAddr('strategist2');

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _managerWithMerkleVerification.setManageRoot(strategist2, root);

    vm.prank(owner);
    _managerWithMerkleVerification.setManageRoot(strategist2, root);

    assertEq(_managerWithMerkleVerification.manageRoot(strategist2), root);
  }

  // merkle root: 0xc07180f6901e597e364bf4c873f952084261ba4d1c2fb40de8ffe98a3cc02030
  // leafs:
  //    [0]: deposit(makeAddr('user1'), uint256)
  //          proofs: [
  //            0x24c791245d8d6777f368aadfb6969609d54392fbf8fe45b8e64fcebe2b0d414e,
  //            0x637690d4869c8b6848a7f10270415fe9a6d2a8f89f21a5ba312dd21a38a06809,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //    [1]: deposit(makeAddr('user2'), uint256)
  //          proofs: [
  //            0x0eac06991ea4eb7dd3f4f39206abfb963e49da453f2fad6bda13a1e5125fb4c5,
  //            0x637690d4869c8b6848a7f10270415fe9a6d2a8f89f21a5ba312dd21a38a06809,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //    [2]: deposit(makeAddr('user3'), uint256)
  //          proofs: [
  //            0xa7a0fd846665d92e66be6155c6221b3acd7145ca7c4e4b67a594e4c516969400,
  //            0x4b1dbd833716a3713994954341418997f137e6d6e71a543ba669e35127038ffc,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //
  // You can check by running below test method.
  //
  // function test_generate_merkle_root() public {
  //   _generateTestVaultMerkleRoot();
  // }

  function _generateTestVaultMerkleRoot() internal {
    leafIndex = 0;

    ManageLeaf[] memory leafs = new ManageLeaf[](8);

    address[] memory accounts = new address[](3);
    accounts[0] = makeAddr('user1');
    accounts[1] = makeAddr('user2');
    accounts[2] = makeAddr('user3');

    _addTestVaultLeafs(leafs, accounts);

    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    _generateLeafs(
      './TemporaryLeafs.json',
      leafs,
      manageTree[manageTree.length - 1][0],
      manageTree,
      address(_strategyExecutor),
      address(_testVaultDecoderAndSanitizer),
      address(_managerWithMerkleVerification)
    );

    bytes32[][] memory proofs = _getProofsUsingTree(leafs, manageTree, address(_testVaultDecoderAndSanitizer));
    for (uint256 i = 0; i < proofs.length; i++) {
      console.log(i);
      for (uint256 j = 0; j < proofs[i].length; j++) {
        console.logBytes32(proofs[i][j]);
      }
      console.log('=======');
    }
  }

  function _addTestVaultLeafs(ManageLeaf[] memory leafs, address[] memory accounts) internal {
    for (uint256 i = 0; i < accounts.length; i++) {
      leafs[leafIndex] = ManageLeaf(
        address(_testVault),
        false,
        'deposit(address,uint256)',
        new address[](1),
        'test',
        address(_testVaultDecoderAndSanitizer)
      );
      leafs[leafIndex].argumentAddresses[0] = accounts[i];
      unchecked {
        leafIndex++;
      }
    }
  }

  function _makeManageParamterForUser1(uint256 amount)
    internal
    view
    returns (
      bytes32[][] memory manageProofs,
      address[] memory decodersAndSanitizers,
      address[] memory targets,
      bytes[] memory targetData,
      uint256[] memory values
    )
  {
    manageProofs = new bytes32[][](1);
    manageProofs[0] = new bytes32[](3);
    manageProofs[0][0] = 0x24c791245d8d6777f368aadfb6969609d54392fbf8fe45b8e64fcebe2b0d414e;
    manageProofs[0][1] = 0x637690d4869c8b6848a7f10270415fe9a6d2a8f89f21a5ba312dd21a38a06809;
    manageProofs[0][2] = 0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe;

    decodersAndSanitizers = new address[](1);
    decodersAndSanitizers[0] = address(_testVaultDecoderAndSanitizer);

    targets = new address[](1);
    targets[0] = address(_testVault);

    targetData = new bytes[](1);
    targetData[0] = abi.encodeCall(_testVault.deposit, (user1, amount));

    values = new uint256[](1);
    values[0] = 0;

    return (manageProofs, decodersAndSanitizers, targets, targetData, values);
  }

  function _makeManageParamterForUser2(uint256 amount)
    internal
    view
    returns (
      bytes32[][] memory manageProofs,
      address[] memory decodersAndSanitizers,
      address[] memory targets,
      bytes[] memory targetData,
      uint256[] memory values
    )
  {
    manageProofs = new bytes32[][](1);
    manageProofs[0] = new bytes32[](3);
    manageProofs[0][0] = 0x0eac06991ea4eb7dd3f4f39206abfb963e49da453f2fad6bda13a1e5125fb4c5;
    manageProofs[0][1] = 0x637690d4869c8b6848a7f10270415fe9a6d2a8f89f21a5ba312dd21a38a06809;
    manageProofs[0][2] = 0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe;

    decodersAndSanitizers = new address[](1);
    decodersAndSanitizers[0] = address(_testVaultDecoderAndSanitizer);

    targets = new address[](1);
    targets[0] = address(_testVault);

    targetData = new bytes[](1);
    targetData[0] = abi.encodeCall(_testVault.deposit, (user2, amount));

    values = new uint256[](1);
    values[0] = 0;

    return (manageProofs, decodersAndSanitizers, targets, targetData, values);
  }

  function _makeManageParamterForUser3(uint256 amount)
    internal
    view
    returns (
      bytes32[][] memory manageProofs,
      address[] memory decodersAndSanitizers,
      address[] memory targets,
      bytes[] memory targetData,
      uint256[] memory values
    )
  {
    manageProofs = new bytes32[][](1);
    manageProofs[0] = new bytes32[](3);
    manageProofs[0][0] = 0xa7a0fd846665d92e66be6155c6221b3acd7145ca7c4e4b67a594e4c516969400;
    manageProofs[0][1] = 0x4b1dbd833716a3713994954341418997f137e6d6e71a543ba669e35127038ffc;
    manageProofs[0][2] = 0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe;

    decodersAndSanitizers = new address[](1);
    decodersAndSanitizers[0] = address(_testVaultDecoderAndSanitizer);

    targets = new address[](1);
    targets[0] = address(_testVault);

    targetData = new bytes[](1);
    targetData[0] = abi.encodeCall(_testVault.deposit, (user3, amount));

    values = new uint256[](1);
    values[0] = 0;

    return (manageProofs, decodersAndSanitizers, targets, targetData, values);
  }

  function _errFailedToVerifyManageProof(address target, bytes memory targetData, uint256 value)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      IManagerWithMerkleVerification.IManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
      target,
      targetData,
      value
    );
  }
}
