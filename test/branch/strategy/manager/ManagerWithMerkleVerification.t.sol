// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { Strings } from '@oz-v5/utils/Strings.sol';

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
import { Toolkit } from '../../../util/Toolkit.sol';

struct ManageLeaf {
  address target;
  bool canSendValue;
  string signature;
  address[] argumentAddresses;
  string description;
  address decoderAndSanitizer;
}

contract ManagerWithMerkleVerificationTest is Toolkit {
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
      strategist, 0x20a074e3733ead014e9338d3cfeaa97fd90530934619a273a6dbcb6eac7cae5f
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

  // merkle root: 0x1fd6bfc64a6ddaa9a753726c2b52e35ccfe497dfc72acf2615a3c8362fe1b6c9
  // leafs:
  //    [0]: deposit(makeAddr('user1'), uint256)
  //          proofs: [
  //            0xa23e194a1cf74afb8fe2f73c879355502cd65f582b83a0f676e29c64653aeace,
  //            0x687c09d0be127ad293ecca1322a0a6e9bfc6808aaf924c3bd3ee003c6ab190d6,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //    [1]: deposit(makeAddr('user2'), uint256)
  //          proofs: [
  //            0xd3c864e25934c445c7459b8f5701ff170103ec6d43c2b553ce23ad41732313f7,
  //            0x687c09d0be127ad293ecca1322a0a6e9bfc6808aaf924c3bd3ee003c6ab190d6,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //    [2]: deposit(makeAddr('user3'), uint256)
  //          proofs: [
  //            0xa7a0fd846665d92e66be6155c6221b3acd7145ca7c4e4b67a594e4c516969400,
  //            0x2eeea706711f701b4da75db0a16fd10cc74d494e20c259dcaf569503f1593007,
  //            0x849eda7a295b642e5ddaf49a30eec4470cf507efa83b4104c0752d069c7638fe,
  //          ]
  //
  // You can check by running below test method.
  //
  // function test_generate_merkle_root() public {
  //   _generateTestVaultMerkleRoot();
  // }

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
    manageProofs[0][0] = 0xa23e194a1cf74afb8fe2f73c879355502cd65f582b83a0f676e29c64653aeace;
    manageProofs[0][1] = 0x687c09d0be127ad293ecca1322a0a6e9bfc6808aaf924c3bd3ee003c6ab190d6;
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
    manageProofs[0][0] = 0xd3c864e25934c445c7459b8f5701ff170103ec6d43c2b553ce23ad41732313f7;
    manageProofs[0][1] = 0x687c09d0be127ad293ecca1322a0a6e9bfc6808aaf924c3bd3ee003c6ab190d6;
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
    manageProofs[0][1] = 0x2eeea706711f701b4da75db0a16fd10cc74d494e20c259dcaf569503f1593007;
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

  //
  // https://github.com/Se7en-Seas/boring-vault/blob/main/test/resources/MerkleTreeHelper/MerkleTreeHelper.sol
  //
  uint256 leafIndex = 0;
  bool addLeafIndex = false;

  function _generateTestVaultMerkleRoot() internal {
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

  function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
    uint256 leafsLength = manageLeafs.length;
    bytes32[][] memory leafs = new bytes32[][](1);
    leafs[0] = new bytes32[](leafsLength);
    for (uint256 i; i < leafsLength; ++i) {
      bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
      bytes memory rawDigest = abi.encodePacked(
        manageLeafs[i].decoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
      );
      uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
      for (uint256 j; j < argumentAddressesLength; ++j) {
        rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
      }
      leafs[0][i] = keccak256(rawDigest);
    }
    tree = _buildTrees(leafs);
  }

  function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
    // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
    uint256 merkleTreeIn_length = merkleTreeIn.length;
    merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
    uint256 layer_length;
    // Iterate through merkleTreeIn to copy over data.
    for (uint256 i; i < merkleTreeIn_length; ++i) {
      layer_length = merkleTreeIn[i].length;
      merkleTreeOut[i] = new bytes32[](layer_length);
      for (uint256 j; j < layer_length; ++j) {
        merkleTreeOut[i][j] = merkleTreeIn[i][j];
      }
    }

    uint256 next_layer_length;
    if (layer_length % 2 != 0) {
      next_layer_length = (layer_length + 1) / 2;
    } else {
      next_layer_length = layer_length / 2;
    }
    merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
    uint256 count;
    for (uint256 i; i < layer_length; i += 2) {
      merkleTreeOut[merkleTreeIn_length][count] =
        _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
      count++;
    }

    if (next_layer_length > 1) {
      // We need to process the next layer of leaves.
      merkleTreeOut = _buildTrees(merkleTreeOut);
    }
  }

  function _generateLeafs(
    string memory filePath,
    ManageLeaf[] memory leafs,
    bytes32 manageRoot,
    bytes32[][] memory manageTree,
    //
    address strategyExecutor,
    address decoderAndSanitizer,
    address manager
  ) internal {
    if (vm.exists(filePath)) {
      // Need to delete it
      vm.removeFile(filePath);
    }
    vm.writeLine(filePath, '{ \"metadata\": ');
    string[] memory composition = new string[](5);
    composition[0] = 'Bytes20(DECODER_AND_SANITIZER_ADDRESS)';
    composition[1] = 'Bytes20(TARGET_ADDRESS)';
    composition[2] = 'Bytes1(CAN_SEND_VALUE)';
    composition[3] = 'Bytes4(TARGET_FUNCTION_SELECTOR)';
    composition[4] = 'Bytes{N*20}(ADDRESS_ARGUMENT_0,...,ADDRESS_ARGUMENT_N)';
    string memory metadata = 'ManageRoot';
    {
      // Determine how many leafs are used.
      uint256 usedLeafCount;
      for (uint256 i; i < leafs.length; ++i) {
        if (leafs[i].target != address(0)) {
          usedLeafCount++;
        }
      }
      vm.serializeUint(metadata, 'LeafCount', usedLeafCount);
    }
    vm.serializeUint(metadata, 'TreeCapacity', leafs.length);
    vm.serializeAddress(metadata, 'StrategyExecutor', strategyExecutor);
    vm.serializeAddress(metadata, 'DecoderAndSanitizerAddress', decoderAndSanitizer);
    vm.serializeAddress(metadata, 'ManagerAddress', manager);
    string memory finalMetadata = vm.serializeBytes32(metadata, 'ManageRoot', manageRoot);

    vm.writeLine(filePath, finalMetadata);
    vm.writeLine(filePath, ',');
    vm.writeLine(filePath, '\"leafs\": [');

    for (uint256 i; i < leafs.length; ++i) {
      string memory leaf = 'leaf';
      if (addLeafIndex) vm.serializeUint(leaf, 'LeafIndex', i);
      vm.serializeAddress(leaf, 'TargetAddress', leafs[i].target);
      vm.serializeAddress(leaf, 'DecoderAndSanitizerAddress', leafs[i].decoderAndSanitizer);
      vm.serializeBool(leaf, 'CanSendValue', leafs[i].canSendValue);
      vm.serializeString(leaf, 'FunctionSignature', leafs[i].signature);
      bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
      string memory selector = Strings.toHexString(uint32(sel), 4);
      vm.serializeString(leaf, 'FunctionSelector', selector);
      bytes memory packedData;
      for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
        packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
      }
      vm.serializeBytes(leaf, 'PackedArgumentAddresses', packedData);
      vm.serializeAddress(leaf, 'AddressArguments', leafs[i].argumentAddresses);
      bytes32 digest = keccak256(
        abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
      );
      vm.serializeBytes32(leaf, 'LeafDigest', digest);

      string memory finalJson = vm.serializeString(leaf, 'Description', leafs[i].description);

      // vm.writeJson(finalJson, filePath);
      vm.writeLine(filePath, finalJson);
      if (i != leafs.length - 1) {
        vm.writeLine(filePath, ',');
      }
    }
    vm.writeLine(filePath, '],');

    string memory merkleTreeName = 'MerkleTree';
    string[][] memory merkleTree = new string[][](manageTree.length);
    for (uint256 k; k < manageTree.length; ++k) {
      merkleTree[k] = new string[](manageTree[k].length);
    }

    for (uint256 i; i < manageTree.length; ++i) {
      for (uint256 j; j < manageTree[i].length; ++j) {
        merkleTree[i][j] = vm.toString(manageTree[i][j]);
      }
    }

    string memory finalMerkleTree;
    for (uint256 i; i < merkleTree.length; ++i) {
      string memory layer = Strings.toString(merkleTree.length - (i + 1));
      finalMerkleTree = vm.serializeString(merkleTreeName, layer, merkleTree[i]);
    }
    vm.writeLine(filePath, '\"MerkleTree\": ');
    vm.writeLine(filePath, finalMerkleTree);
    vm.writeLine(filePath, '}');
  }

  function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree, address decoderAndSanitizer)
    internal
    pure
    returns (bytes32[][] memory proofs)
  {
    proofs = new bytes32[][](manageLeafs.length);
    for (uint256 i; i < manageLeafs.length; ++i) {
      if (manageLeafs[i].decoderAndSanitizer == address(0)) continue;
      // Generate manage proof.
      bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
      bytes memory rawDigest =
        abi.encodePacked(decoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector);
      uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
      for (uint256 j; j < argumentAddressesLength; ++j) {
        rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
      }
      bytes32 leaf = keccak256(rawDigest);
      proofs[i] = _generateProof(leaf, tree);
    }
  }

  function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
    // The length of each proof is the height of the tree - 1.
    uint256 tree_length = tree.length;
    proof = new bytes32[](tree_length - 1);

    // Build the proof
    for (uint256 i; i < tree_length - 1; ++i) {
      // For each layer we need to find the leaf.
      for (uint256 j; j < tree[i].length; ++j) {
        if (leaf == tree[i][j]) {
          // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
          proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
          leaf = _hashPair(leaf, proof[i]);
          break;
        } else if (j == tree[i].length - 1) {
          // We have reached the end of the layer and have not found the leaf.
          revert('Leaf not found in tree');
        }
      }
    }
  }

  function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
    return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
  }

  function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x00, a)
      mstore(0x20, b)
      value := keccak256(0x00, 0x40)
    }
  }
}
