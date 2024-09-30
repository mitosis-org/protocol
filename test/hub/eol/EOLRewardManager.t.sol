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

  function test_routeYield_case_Unspecified() public {
    _token.mint(address(_assetManager), 100 ether);

    vm.startPrank(address(_assetManager));

    _token.approve(address(_eolRewardManager), 100 ether);
    _eolRewardManager.routeYield(address(_eolVault), 100 ether);

    vm.stopPrank();

    // vm.startPrank(user1);

    // _token.approve(address(_eolVault), 100 ether);
    // _eolVault.deposit(100 ether, user1);

    // vm.stopPrank();
  }

  function test_routeYield_case_TWAB() public { }
  function test_routeYield_case_MerkleProof() public { }
  function test_routeYield_Unauthorized() public { }
  function test_routeYield_DefaultDistributorNotSet() public { }

  function test_routeExtraRewards_case_Unspecified() public { }
  function test_routeExtraRewards_case_TWAB() public { }
  function test_routeExtraRewards_case_MerkleProof() public { }
  function test_routeExtraRewards_Unauthorized() public { }
  function test_routeExtraRewards_DefaultDistributorNotSet() public { }

  function test_dispatchTo() public { }
  function test_dispatchTo_Unauthorized() public { }
  function test_dispatchTo_DistributorNotRegistered() public { }
  function test_dispatchTo_InvalidDispatchRequest() public { }

  function test_dispatchTo_batch() public { }
  function test_dispatchTo_batch_Unauthorized() public { }
  function test_dispatchTo_batch_DistributorNotRegistered() public { }
  function test_dispatchTo_batch_InvalidDispatchRequest() public { }
}
