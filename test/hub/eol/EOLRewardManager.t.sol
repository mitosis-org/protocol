// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { EOLRewardConfigurator } from '../../../src/hub/eol/EOLRewardConfigurator.sol';
import { EOLRewardManager } from '../../../src/hub/eol/EOLRewardManager.sol';
import { EOLVault } from '../../../src/hub/eol/EOLVault.sol';
import { IEOLRewardConfigurator } from '../../../src/interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../../../src/interfaces/hub/reward/IRewardDistributor.sol';
import { IERC20TWABSnapshots } from '../../../src/interfaces/twab/IERC20TWABSnapshots.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockAssetManager } from '../../mock/MockAssetManager.t.sol';
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';
import { MockDistributor } from '../../mock/MockDistributor.t.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EOLRewardManagerTest is Toolkit {
  MockAssetManager _assetManager;
  EOLRewardConfigurator _eolRewardConfigurator;
  EOLRewardManager _eolRewardManager;

  MockDelegationRegistry _delegationRegistry;
  MockERC20TWABSnapshots _token;
  EOLVault _eolVault;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');
  address immutable user1 = makeAddr('user1');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    _assetManager = new MockAssetManager();

    EOLRewardConfigurator eolRewardConfiguratorImpl = new EOLRewardConfigurator();
    _eolRewardConfigurator = EOLRewardConfigurator(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolRewardConfiguratorImpl),
            address(_proxyAdmin),
            abi.encodeCall(_eolRewardConfigurator.initialize, (owner))
          )
        )
      )
    );

    EOLRewardManager eolRewardManagerImpl = new EOLRewardManager();
    _eolRewardManager = EOLRewardManager(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolRewardManagerImpl),
            address(_proxyAdmin),
            abi.encodeCall(
              _eolRewardManager.initialize, (owner, address(_assetManager), address(_eolRewardConfigurator))
            )
          )
        )
      )
    );

    _delegationRegistry = new MockDelegationRegistry();

    _token = new MockERC20TWABSnapshots();
    _token.initialize(address(_delegationRegistry), 'Token', 'TKN');

    EOLVault eolVaultImpl = new EOLVault();
    _eolVault = EOLVault(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolVaultImpl),
            address(_proxyAdmin),
            abi.encodeCall(
              _eolVault.initialize,
              (address(_delegationRegistry), address(_assetManager), IERC20TWABSnapshots(address(_token)), '', '')
            )
          )
        )
      )
    );
  }

  function test_routeExtraRewards_case_Unspecified() public {
    _token.mint(address(_assetManager), 100 ether);

    vm.startPrank(address(_assetManager));

    _token.approve(address(_eolRewardManager), 100 ether);
    _eolRewardManager.routeExtraRewards(address(_eolVault), address(_token), 100 ether);

    vm.stopPrank();

    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);
  }

  function test_routeExtraRewards_case_Unspecified_DiffReward() public {
    MockERC20TWABSnapshots rewardToken = new MockERC20TWABSnapshots();
    rewardToken.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    rewardToken.mint(address(_assetManager), 100 ether);

    vm.startPrank(address(_assetManager));

    rewardToken.approve(address(_eolRewardManager), 100 ether);
    _eolRewardManager.routeExtraRewards(address(_eolVault), address(rewardToken), 100 ether);

    vm.stopPrank();

    assertEq(rewardToken.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(rewardToken), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);
  }

  function test_routeExtraRewards_case_TWAB() public {
    vm.startPrank(owner);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardConfigurator.setDefaultDistributor(distributor);
    _eolRewardConfigurator.setRewardDistributionType(address(_eolVault), address(_token), DistributionType.TWAB);

    vm.stopPrank();

    _token.mint(address(_assetManager), 100 ether);

    vm.startPrank(address(_assetManager));

    _token.approve(address(_eolRewardManager), 100 ether);
    _eolRewardManager.routeExtraRewards(address(_eolVault), address(_token), 100 ether);

    vm.stopPrank();

    assertEq(_token.balanceOf(address(distributor)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));
    assertEq(rewards.length, 0);
  }

  function test_routeExtraRewards_case_MerkleProof() public {
    vm.startPrank(owner);

    MockDistributor distributor = new MockDistributor(DistributionType.MerkleProof, address(_eolRewardConfigurator));
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardConfigurator.setDefaultDistributor(distributor);
    _eolRewardConfigurator.setRewardDistributionType(address(_eolVault), address(_token), DistributionType.MerkleProof);

    vm.stopPrank();

    _token.mint(address(_assetManager), 100 ether);

    vm.startPrank(address(_assetManager));

    _token.approve(address(_eolRewardManager), 100 ether);
    _eolRewardManager.routeExtraRewards(address(_eolVault), address(_token), 100 ether);

    vm.stopPrank();

    assertEq(_token.balanceOf(address(distributor)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));
    assertEq(rewards.length, 0);
  }

  function test_routeExtraRewards_Unauthorized() public {
    _token.mint(address(_assetManager), 100 ether);

    vm.prank(address(_assetManager));
    _token.approve(address(_eolRewardManager), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolRewardManager.routeExtraRewards(address(_eolVault), address(_token), 100 ether);
  }

  function test_dispatchTo() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);
    _eolRewardManager.dispatchTo(distributor, address(_eolVault), address(_token), uint48(block.timestamp), 0, '');
    vm.stopPrank();

    assertEq(_token.balanceOf(address(distributor)), 100 ether);
  }

  function test_dispatchTo_Unauthorized() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.prank(owner);
    _eolRewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolRewardManager.dispatchTo(distributor, address(_eolVault), address(_token), uint48(block.timestamp), 0, '');
  }

  function test_dispatchTo_RewardDistributorNotRegistered() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    // _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);

    vm.expectRevert(_errRewardDistributorNotRegistered());
    _eolRewardManager.dispatchTo(distributor, address(_eolVault), address(_token), uint48(block.timestamp), 0, '');

    vm.stopPrank();
  }

  function test_dispatchTo_batch() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);
    vm.stopPrank();

    uint256[] memory indexes = new uint256[](1);
    bytes[] memory metadata = new bytes[](1);

    indexes[0] = 0;
    metadata[0] = '';

    vm.prank(owner);
    _eolRewardManager.dispatchTo(
      distributor, address(_eolVault), address(_token), uint48(block.timestamp), indexes, metadata
    );

    assertEq(_token.balanceOf(address(distributor)), 100 ether);
  }

  function test_dispatchTo_batch_Unauthorized() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);
    vm.stopPrank();

    uint256[] memory indexes = new uint256[](1);
    bytes[] memory metadata = new bytes[](1);

    indexes[0] = 0;
    metadata[0] = '';

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolRewardManager.dispatchTo(
      distributor, address(_eolVault), address(_token), uint48(block.timestamp), indexes, metadata
    );
  }

  function test_dispatchTo_batch_DistributorNotRegistered() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    // _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);
    vm.stopPrank();

    uint256[] memory indexes = new uint256[](1);
    bytes[] memory metadata = new bytes[](1);

    indexes[0] = 0;
    metadata[0] = '';

    vm.startPrank(owner);

    vm.expectRevert(_errRewardDistributorNotRegistered());
    _eolRewardManager.dispatchTo(
      distributor, address(_eolVault), address(_token), uint48(block.timestamp), indexes, metadata
    );

    vm.stopPrank();
  }

  function test_dispatchTo_batch_InvalidParameter() public {
    test_routeExtraRewards_case_Unspecified();
    assertEq(_token.balanceOf(address(_eolRewardManager)), 100 ether);

    (uint256[] memory rewards,) =
      _eolRewardManager.getRewardTreasuryRewardInfos(address(_eolVault), address(_token), uint48(block.timestamp));

    assertEq(rewards.length, 1);
    assertEq(rewards[0], 100 ether);

    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(_eolRewardConfigurator));

    vm.startPrank(owner);
    _eolRewardConfigurator.registerDistributor(distributor);
    _eolRewardManager.setRewardManager(owner);
    vm.stopPrank();

    uint256[] memory indexes = new uint256[](1);
    bytes[] memory metadata = new bytes[](2);

    indexes[0] = 0;
    // indexes[1] = 1;
    metadata[0] = '';
    metadata[1] = '';

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidParameter('metadata'));
    _eolRewardManager.dispatchTo(
      distributor, address(_eolVault), address(_token), uint48(block.timestamp), indexes, metadata
    );

    vm.stopPrank();
  }

  function test_setRewardManager() public {
    assertFalse(_eolRewardManager.isRewardManager(address(1)));

    vm.prank(owner);
    _eolRewardManager.setRewardManager(address(1));

    assertTrue(_eolRewardManager.isRewardManager(address(1)));
  }

  function test_setRewardManager_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolRewardManager.setRewardManager(address(1));
  }

  function _errRewardDistributorNotRegistered() internal pure returns (bytes memory) {
    return
      abi.encodeWithSelector(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered.selector);
  }
}
