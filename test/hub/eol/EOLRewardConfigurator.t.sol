// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { EOLRewardConfigurator } from '../../../src/hub/eol/EOLRewardConfigurator.sol';
import { IEOLRewardConfigurator } from '../../../src/interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IRewardDistributor, DistributionType } from '../../../src/interfaces/hub/reward/IRewardDistributor.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockDistributor } from '../../mock/MockDistributor.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract EOLRewardConfiguratorTest is Test, Toolkit {
  EOLRewardConfigurator rewardConfigurator;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = makeAddr('owner');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);

    EOLRewardConfigurator rewardConfiguratorImpl = new EOLRewardConfigurator();
    rewardConfigurator = EOLRewardConfigurator(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(rewardConfiguratorImpl),
            address(_proxyAdmin),
            abi.encodeCall(rewardConfigurator.initialize, (owner))
          )
        )
      )
    );
  }

  function test_registerDistributor() public {
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    MockDistributor distributor3 = new MockDistributor(DistributionType.MerkleProof, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor1);
    assertTrue(rewardConfigurator.isDistributorRegistered(distributor1));

    rewardConfigurator.registerDistributor(distributor2);
    assertTrue(rewardConfigurator.isDistributorRegistered(distributor2));

    rewardConfigurator.registerDistributor(distributor3);
    assertTrue(rewardConfigurator.isDistributorRegistered(distributor3));

    vm.stopPrank();
  }

  function test_registerDistributor_Unauthroized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    rewardConfigurator.registerDistributor(distributor);
  }

  function test_registerDistributor_RewardDistributorAlreadyRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(_errRewardDistributorAlreadyRegistered());
    rewardConfigurator.registerDistributor(distributor);

    vm.stopPrank();
  }

  function test_registerDistributor_InvalidRewardConfigurator() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(1));

    vm.startPrank(owner);

    vm.expectRevert(_errInvalidRewardDistributor());
    rewardConfigurator.registerDistributor(distributor);

    distributor.setRewardConfigurator(address(rewardConfigurator));

    rewardConfigurator.registerDistributor(distributor);

    vm.stopPrank();
  }

  function test_unregisterDistributor() public {
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    MockDistributor distributor3 = new MockDistributor(DistributionType.MerkleProof, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor1);
    rewardConfigurator.registerDistributor(distributor2);
    rewardConfigurator.registerDistributor(distributor3);

    rewardConfigurator.unregisterDistributor(distributor1);
    assertFalse(rewardConfigurator.isDistributorRegistered(distributor1));

    rewardConfigurator.unregisterDistributor(distributor2);
    assertFalse(rewardConfigurator.isDistributorRegistered(distributor2));

    rewardConfigurator.unregisterDistributor(distributor3);
    assertFalse(rewardConfigurator.isDistributorRegistered(distributor3));

    vm.stopPrank();
  }

  function test_unregisterDistributor_Unauthorized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.prank(owner);
    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    rewardConfigurator.unregisterDistributor(distributor);
  }

  function test_unregisterDistributor_RewardDistributorNotRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    vm.expectRevert(_errRewardDistributorNotRegistered());
    rewardConfigurator.unregisterDistributor(distributor);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.unregisterDistributor(distributor);

    vm.expectRevert(_errRewardDistributorNotRegistered());
    rewardConfigurator.unregisterDistributor(distributor);

    vm.stopPrank();
  }

  function test_unregisterDistributor_UnregisterDefaultDistributorNotAllowed() public {
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor1);
    rewardConfigurator.registerDistributor(distributor2);

    rewardConfigurator.setDefaultDistributor(distributor1);

    vm.expectRevert(_errUnregisterDefaultDistributorNotAllowed());
    rewardConfigurator.unregisterDistributor(distributor1);

    // change default distributor for unregister
    rewardConfigurator.setDefaultDistributor(distributor2);

    rewardConfigurator.unregisterDistributor(distributor1);

    vm.stopPrank();
  }

  function test_setDefaultDistributor() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    IRewardDistributor defaultDistributor = rewardConfigurator.defaultDistributor(DistributionType.TWAB);
    assertTrue(address(distributor) == address(defaultDistributor));

    vm.stopPrank();
  }

  function test_setDefaultDistributor_Unauthorized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.prank(owner);
    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    rewardConfigurator.setDefaultDistributor(distributor);
  }

  function test_setDefaultDistributor_RewardDistributorNotRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    vm.expectRevert(_errRewardDistributorNotRegistered());
    rewardConfigurator.setDefaultDistributor(distributor);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    vm.stopPrank();
  }

  function test_setRewardDistributionType() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    address eolVault = makeAddr('eolVault');
    address asset = makeAddr('asset');

    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);
    assertTrue(rewardConfigurator.distributionType(eolVault, asset) == DistributionType.TWAB);

    assertTrue(rewardConfigurator.distributionType(address(0), address(0)) == DistributionType.Unspecified);

    vm.stopPrank();
  }

  function test_setRewardDistributionType_Unauthorized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    vm.stopPrank();

    address eolVault = makeAddr('eolVault');
    address asset = makeAddr('asset');

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);
  }

  function test_setRewardDistributionType_DefaultDistributorNotSet() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB, address(rewardConfigurator));

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    // rewardConfigurator.setDefaultDistributor(distributor);

    address eolVault = makeAddr('eolVault');
    address asset = makeAddr('asset');

    vm.expectRevert(_errDefaultDistributorNotSet(DistributionType.TWAB));
    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);

    vm.stopPrank();
  }

  function _errRewardDistributorAlreadyRegistered() internal pure returns (bytes memory) {
    return
      abi.encodeWithSelector(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorAlreadyRegistered.selector);
  }

  function _errInvalidRewardDistributor() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IEOLRewardConfigurator.IEOLRewardConfigurator__InvalidRewardConfigurator.selector);
  }

  function _errRewardDistributorNotRegistered() internal pure returns (bytes memory) {
    return
      abi.encodeWithSelector(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered.selector);
  }

  function _errUnregisterDefaultDistributorNotAllowed() internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IEOLRewardConfigurator.IEOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed.selector
    );
  }

  function _errDefaultDistributorNotSet(DistributionType distributionType) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IEOLRewardConfigurator.IEOLRewardConfigurator__DefaultDistributorNotSet.selector, distributionType
    );
  }
}
