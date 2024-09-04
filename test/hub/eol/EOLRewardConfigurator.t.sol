// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console } from '@std/console.sol';
import { Test } from '@std/Test.sol';
import { Vm } from '@std/Vm.sol';

import { IERC20Errors } from '@oz-v5/interfaces/draft-IERC6093.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { EOLRewardConfigurator } from '../../../src/hub/eol/EOLRewardConfigurator.sol';
import { DistributionType } from '../../../src/interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { IEOLRewardDistributor } from '../../../src/interfaces/hub/eol/IEOLRewardDistributor.sol';
import { IEOLRewardConfigurator } from '../../../src/interfaces/hub/eol/IEOLRewardConfigurator.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MockDistributor is IEOLRewardDistributor {
  DistributionType _distributionType;

  constructor(DistributionType distributionType_) {
    _distributionType = distributionType_;
  }

  function distributionType() external view returns (DistributionType) {
    return _distributionType;
  }

  function description() external view returns (string memory) {
    return 'MockDistributor';
  }

  function claimable(address account, address eolVault, address asset) external view returns (bool) {
    return true;
  }

  function handleReward(address eolVault, address asset, uint256 amount, bytes memory metadata) external {
    return;
  }
}

contract HubAssetTest is Test, Toolkit {
  EOLRewardConfigurator rewardConfigurator;

  ProxyAdmin internal _proxyAdmin;
  address immutable owner = _addr('owner');
  address immutable user1 = _addr('user1');

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
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB);
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB);
    MockDistributor distributor3 = new MockDistributor(DistributionType.MerkleProof);

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
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);
    vm.expectRevert(); // onlyOwner
    rewardConfigurator.registerDistributor(distributor);
  }

  function test_registerDistributor_RewardDistributorAlreadyRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorAlreadyRegistered.selector);
    rewardConfigurator.registerDistributor(distributor);

    vm.stopPrank();
  }

  function test_unregisterDistributor() public {
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB);
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB);
    MockDistributor distributor3 = new MockDistributor(DistributionType.MerkleProof);

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
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.prank(owner);
    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert(); // onlyOwner
    rewardConfigurator.unregisterDistributor(distributor);
  }

  function test_unregisterDistributor_RewardDistributorNotRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    vm.expectRevert(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered.selector);
    rewardConfigurator.unregisterDistributor(distributor);

    vm.stopPrank();
  }

  function test_unregisterDistributor_UnregisterDefaultDistributorNotAllowed() public {
    MockDistributor distributor1 = new MockDistributor(DistributionType.TWAB);
    MockDistributor distributor2 = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor1);
    rewardConfigurator.registerDistributor(distributor2);

    rewardConfigurator.setDefaultDistributor(distributor1);

    vm.expectRevert(EOLRewardConfigurator.EOLRewardConfigurator__UnregisterDefaultDistributorNotAllowed.selector);
    rewardConfigurator.unregisterDistributor(distributor1);

    // change default distributor for unregister
    rewardConfigurator.setDefaultDistributor(distributor2);

    rewardConfigurator.unregisterDistributor(distributor1);

    vm.stopPrank();
  }

  function test_setDefaultDistributor() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    IEOLRewardDistributor defaultDistributor = rewardConfigurator.getDefaultDistributor(DistributionType.TWAB);
    assertTrue(address(distributor) == address(defaultDistributor));

    vm.stopPrank();
  }

  function test_setDefaultDistributor_Unauthorized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.prank(owner);
    rewardConfigurator.registerDistributor(distributor);

    vm.expectRevert();
    rewardConfigurator.setDefaultDistributor(distributor);
  }

  function test_setDefaultDistributor_RewardDistributorNotRegistered() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    vm.expectRevert(IEOLRewardConfigurator.IEOLRewardConfigurator__RewardDistributorNotRegistered.selector);
    rewardConfigurator.setDefaultDistributor(distributor);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    vm.stopPrank();
  }

  function test_setRewardDistributionType() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    address eolVault = _addr('eolVault');
    address asset = _addr('asset');

    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);
    assertTrue(rewardConfigurator.getDistributionType(eolVault, asset) == DistributionType.TWAB);

    assertTrue(rewardConfigurator.getDistributionType(address(0), address(0)) == DistributionType.Unspecified);

    vm.stopPrank();
  }

  function test_setRewardDistributionType_Unauthorized() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    rewardConfigurator.setDefaultDistributor(distributor);

    vm.stopPrank();

    address eolVault = _addr('eolVault');
    address asset = _addr('asset');

    vm.expectRevert();
    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);
  }

  function test_setRewardDistributionType_DefaultDistributorNotSet() public {
    MockDistributor distributor = new MockDistributor(DistributionType.TWAB);

    vm.startPrank(owner);

    rewardConfigurator.registerDistributor(distributor);
    // rewardConfigurator.setDefaultDistributor(distributor);

    address eolVault = _addr('eolVault');
    address asset = _addr('asset');

    vm.expectRevert(
      abi.encodeWithSelector(
        EOLRewardConfigurator.EOLRewardConfigurator__DefaultDistributorNotSet.selector, DistributionType.TWAB
      )
    );
    rewardConfigurator.setRewardDistributionType(eolVault, asset, DistributionType.TWAB);

    vm.stopPrank();
  }
}
