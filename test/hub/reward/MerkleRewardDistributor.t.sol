// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import { Merkle } from '@murky/Merkle.sol';

// import { WETH } from '@solady/tokens/WETH.sol';

// import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
// import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

// import {
//   LibDistributorRewardMetadata, RewardMerkleMetadata
// } from '../../../src/hub/reward/LibDistributorRewardMetadata.sol';
// import { MerkleRewardDistributor } from '../../../src/hub/reward/MerkleRewardDistributor.sol';
// import { IMerkleRewardDistributor } from '../../../src/interfaces/hub/reward/IMerkleRewardDistributor.sol';
// import { Toolkit } from '../../util/Toolkit.sol';

// contract MerkleRewardDistributorTest is Toolkit {
//   using LibDistributorRewardMetadata for bytes;
//   using LibDistributorRewardMetadata for RewardMerkleMetadata;

//   struct LeafBase {
//     address eolVault;
//     address reward;
//     uint256 stage;
//   }

//   struct Leaf {
//     LeafBase base;
//     address account;
//     uint256 amount;
//   }

//   address internal _owner = makeAddr('owner');
//   address internal _rewardManager = makeAddr('rewardManager');
//   address internal _rewardConfigurator = makeAddr('rewardConfigurator');

//   Merkle internal _merkle;
//   WETH internal _weth;

//   ProxyAdmin internal _proxyAdmin;
//   MerkleRewardDistributor internal _distributorImpl;
//   MerkleRewardDistributor internal _distributor;

//   function setUp() public {
//     _merkle = new Merkle();
//     _weth = new WETH();

//     _proxyAdmin = new ProxyAdmin(_owner);
//     _distributorImpl = new MerkleRewardDistributor();
//     _distributor = MerkleRewardDistributor(
//       address(
//         new TransparentUpgradeableProxy(
//           address(_distributorImpl),
//           address(_proxyAdmin),
//           abi.encodeCall(_distributorImpl.initialize, (_owner, _rewardManager, _rewardConfigurator))
//         )
//       )
//     );
//   }

//   function test_claim() public {
//     LeafBase memory base = LeafBase({ eolVault: makeAddr('eolVault'), reward: address(_weth), stage: 1 });
//     Leaf[] memory leaves = new Leaf[](3);

//     leaves[0] = _makeLeaf(base, makeAddr('user-a'), 1 ether);
//     leaves[1] = _makeLeaf(base, makeAddr('user-b'), 2 ether);
//     leaves[2] = _makeLeaf(base, makeAddr('user-c'), 3 ether);

//     (bytes32 root,, bytes32[][] memory proofs) = _makeTree(leaves);
//     _submitReward(base, 6 ether, root);

//     for (uint256 i = 0; i < leaves.length; i++) {
//       vm.startPrank(leaves[i].account);

//       bytes memory metadata = _leafToMetadata(leaves[i], proofs[i]);

//       // before claim
//       assertTrue(_distributor.claimable(leaves[i].account, base.reward, metadata));
//       assertEq(_distributor.claimableAmount(leaves[i].account, base.reward, metadata), leaves[i].amount);

//       _distributor.claim(base.reward, metadata);

//       // after claim
//       assertFalse(_distributor.claimable(leaves[i].account, base.reward, metadata));
//       assertEq(_distributor.claimableAmount(leaves[i].account, base.reward, metadata), 0);

//       vm.expectRevert(_errAlreadyClaimed());
//       _distributor.claim(base.reward, metadata);

//       vm.stopPrank();
//     }
//   }

//   function _submitReward(LeafBase memory base, uint256 amount, bytes32 root) internal {
//     vm.startPrank(_rewardManager);

//     vm.deal(_rewardManager, amount);
//     _weth.deposit{ value: amount }();
//     _weth.approve(address(_distributor), amount);

//     _distributor.handleReward(base.eolVault, base.reward, amount, abi.encode(base.stage, root));

//     vm.stopPrank();
//   }

//   function _makeLeaf(LeafBase memory base, address account, uint256 amount) internal pure returns (Leaf memory) {
//     return Leaf({ base: base, account: account, amount: amount });
//   }

//   function _makeTree(Leaf[] memory leaves)
//     internal
//     view
//     returns (bytes32 root, bytes32[] memory tree, bytes32[][] memory proofs)
//   {
//     tree = new bytes32[](leaves.length);
//     for (uint256 i = 0; i < leaves.length; i++) {
//       tree[i] = _encodeLeaf(leaves[i]);
//     }

//     proofs = new bytes32[][](leaves.length);
//     for (uint256 i = 0; i < leaves.length; i++) {
//       proofs[i] = _merkle.getProof(tree, i);
//     }

//     return (_merkle.getRoot(tree), tree, proofs);
//   }

//   function _encodeLeaf(Leaf memory leaf) internal view returns (bytes32) {
//     return _distributor.encodeLeaf(leaf.base.eolVault, leaf.base.reward, leaf.base.stage, leaf.account, leaf.amount);
//   }

//   function _leafToMetadata(Leaf memory leaf, bytes32[] memory proof) internal pure returns (bytes memory) {
//     return RewardMerkleMetadata({
//       eolVault: leaf.base.eolVault,
//       stage: leaf.base.stage,
//       amount: leaf.amount,
//       proof: proof
//     }).encode();
//   }

//   function _errAlreadyClaimed() internal pure returns (bytes memory) {
//     return abi.encodeWithSelector(IMerkleRewardDistributor.IMerkleRewardDistributor__AlreadyClaimed.selector);
//   }

//   function _errInvalidProof() internal pure returns (bytes memory) {
//     return abi.encodeWithSelector(IMerkleRewardDistributor.IMerkleRewardDistributor__InvalidProof.selector);
//   }
// }
