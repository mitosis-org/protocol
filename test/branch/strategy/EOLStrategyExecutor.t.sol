// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { console } from '@std/console.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';
import { Address } from '@oz-v5/utils/Address.sol';

import { MitosisVault, AssetAction, EOLAction } from '../../../src/branch/MitosisVault.sol';
import { EOLStrategyExecutor } from '../../../src/branch/strategy/EOLStrategyExecutor.sol';
import { IMitosisVault } from '../../../src/interfaces/branch/IMitosisVault.sol';
import { IMitosisVaultEntrypoint } from '../../../src/interfaces/branch/IMitosisVaultEntrypoint.sol';
import { IEOLStrategyExecutor } from '../../../src/interfaces/branch/strategy/IEOLStrategyExecutor.sol';
import { Pausable } from '../../../src/lib/Pausable.sol';
import { StdError } from '../../../src/lib/StdError.sol';
import { MockDelegationRegistry } from '../../mock/MockDelegationRegistry.t.sol';
import { MockEOLStrategyExecutor } from '../../mock/MockEOLStrategyExecutor.t.sol';
import { MockERC20TWABSnapshots } from '../../mock/MockERC20TWABSnapshots.t.sol';
import { MockMitosisVaultEntrypoint } from '../../mock/MockMitosisVaultEntrypoint.t.sol';
import { MockStrategy } from '../../mock/MockStrategy.t.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract MitosisVaultTest is Toolkit {
  EOLStrategyExecutor _eolStrategyExecutor;
  MitosisVault _mitosisVault;
  MockMitosisVaultEntrypoint _mitosisVaultEntrypoint;
  ProxyAdmin _proxyAdmin;
  MockERC20TWABSnapshots _token;
  MockDelegationRegistry _delegationRegistry;

  address immutable owner = makeAddr('owner');
  address immutable mitosis = makeAddr('mitosis'); // TODO: replace with actual contract
  address immutable emergencyManager = makeAddr('emergencyManager');
  address immutable strategist = makeAddr('strategist');
  address immutable hubEOLVault = makeAddr('hubEOLVault');

  function setUp() public {
    _delegationRegistry = new MockDelegationRegistry(mitosis);
    _proxyAdmin = new ProxyAdmin(owner);

    MitosisVault mitosisVaultImpl = new MitosisVault();
    _mitosisVault = MitosisVault(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(mitosisVaultImpl), address(_proxyAdmin), abi.encodeCall(mitosisVaultImpl.initialize, (owner))
          )
        )
      )
    );

    _mitosisVaultEntrypoint = new MockMitosisVaultEntrypoint();

    _token = new MockERC20TWABSnapshots();
    _token.initialize(address(_delegationRegistry), 'Token', 'TKN');

    EOLStrategyExecutor eolStrategyExecutorImpl = new EOLStrategyExecutor();
    _eolStrategyExecutor = EOLStrategyExecutor(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(eolStrategyExecutorImpl),
            address(_proxyAdmin),
            abi.encodeCall(
              eolStrategyExecutorImpl.initialize,
              (_mitosisVault, IERC20(address(_token)), hubEOLVault, owner, emergencyManager)
            )
          )
        )
      )
    );

    vm.prank(owner);
    _mitosisVault.setEntrypoint(address(_mitosisVaultEntrypoint));

    vm.startPrank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(_token));
    _mitosisVault.initializeEOL(hubEOLVault, address(_token));
    vm.stopPrank();

    vm.prank(owner);
    _mitosisVault.setEOLStrategyExecutor(hubEOLVault, address(_eolStrategyExecutor));

    vm.prank(owner);
    _eolStrategyExecutor.setStrategist(strategist);
  }

  function test_deallocateEOL() public {
    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.allocateEOL(hubEOLVault, 100 ether);

    vm.prank(strategist);
    _eolStrategyExecutor.deallocateEOL(100 ether);
  }

  function test_deallocateEOL_Paused() public {
    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.allocateEOL(hubEOLVault, 100 ether);

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.deallocateEOL.selector));
    _eolStrategyExecutor.deallocateEOL(100 ether);

    vm.stopPrank();
  }

  function test_deallocateEOL_Unauthorized() public {
    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.allocateEOL(hubEOLVault, 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.deallocateEOL(100 ether);
  }

  function test_fetchEOL() public {
    _allocateEOL(100 ether);
    _fetchEOL(80 ether);
  }

  function test_fetchEOL_Paused() public {
    _allocateEOL(100 ether);

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.fetchEOL.selector));
    _eolStrategyExecutor.fetchEOL(80 ether);

    vm.stopPrank();
  }

  function test_fetchEOL_Unauthorized() public {
    _allocateEOL(100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.fetchEOL(100 ether);
  }

  function test_fetchEOL_AmountExceeded() public {
    _allocateEOL(100 ether);

    vm.startPrank(strategist);

    vm.expectRevert();
    _eolStrategyExecutor.fetchEOL(101 ether);

    vm.stopPrank();
  }

  function test_returnEOL() public {
    _allocateEOL(100 ether);
    _fetchEOL(100 ether);
    _returnEOL(30 ether);
  }

  function test_returnEOL_Paused() public {
    _allocateEOL(100 ether);
    _fetchEOL(100 ether);

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.returnEOL.selector));
    _eolStrategyExecutor.returnEOL(30 ether);

    vm.stopPrank();
  }

  function test_returnEOL_Unauthorized() public {
    _allocateEOL(100 ether);
    _fetchEOL(100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.returnEOL(30 ether);
  }

  function test_returnEOL_AmountExceeded() public {
    _allocateEOL(100 ether);
    _fetchEOL(100 ether);
    _token.mint(address(_eolStrategyExecutor), 30 ether);

    vm.startPrank(strategist);

    // Note that the strategy executor can't return EOL amount not settled yet even though it has the amount enough.
    vm.expectRevert();
    _eolStrategyExecutor.returnEOL(101 ether);

    vm.stopPrank();
  }

  function test_settle_yield() public {
    _allocateEOL(100 ether);
    _fetchEOL(10 ether);

    MockStrategy strategy1 = new MockStrategy(address(_token));
    MockStrategy strategy2 = new MockStrategy(address(_token));
    strategy1.setBalance(100 ether);
    strategy2.setBalance(50 ether);

    vm.startPrank(owner);
    _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.addStrategy(1, address(strategy2), '');
    vm.stopPrank();

    vm.startPrank(strategist);

    vm.expectCall(
      address(_mitosisVault), abi.encodeWithSelector(MitosisVault.settleYield.selector, hubEOLVault, 150 ether)
    );
    _eolStrategyExecutor.settle();

    vm.stopPrank();

    assertEq(_eolStrategyExecutor.storedTotalBalance(), 10 ether + 150 ether);
  }

  function test_settle_loss() public {
    _allocateEOL(100 ether);
    _fetchEOL(10 ether);

    MockStrategy strategy1 = new MockStrategy(address(_token));
    MockStrategy strategy2 = new MockStrategy(address(_token));
    strategy1.setBalance(100 ether);
    strategy2.setBalance(50 ether);

    vm.startPrank(owner);
    _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.addStrategy(1, address(strategy2), '');
    vm.stopPrank();

    vm.prank(strategist);
    _eolStrategyExecutor.settle();

    assertEq(_eolStrategyExecutor.storedTotalBalance(), 10 ether + 150 ether);

    // Loss
    // strategy1: 100 ether -> 70 ether
    // strategy2: 50 ether -> 30 ether
    strategy1.setBalance(70 ether);
    strategy2.setBalance(30 ether);

    vm.startPrank(strategist);

    vm.expectCall(
      address(_mitosisVault),
      abi.encodeWithSelector(MitosisVault.settleLoss.selector, hubEOLVault, 150 ether - 100 ether)
    );
    _eolStrategyExecutor.settle();

    vm.stopPrank();

    assertEq(_eolStrategyExecutor.storedTotalBalance(), 10 ether + 100 ether);
  }

  function test_settle_Paused() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));
    MockStrategy strategy2 = new MockStrategy(address(_token));
    strategy1.setBalance(100 ether);
    strategy2.setBalance(50 ether);

    vm.startPrank(owner);
    _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.addStrategy(1, address(strategy2), '');

    _eolStrategyExecutor.pause();
    vm.stopPrank();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.settle.selector));
    _eolStrategyExecutor.settle();

    vm.stopPrank();
  }

  function test_settle_Unauthorized() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));
    MockStrategy strategy2 = new MockStrategy(address(_token));
    strategy1.setBalance(100 ether);
    strategy2.setBalance(50 ether);

    vm.startPrank(owner);
    _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.addStrategy(1, address(strategy2), '');
    vm.stopPrank();

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.settle();
  }

  function test_settleExtraRewards() public {
    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(reward));

    reward.mint(address(_eolStrategyExecutor), 100 ether);

    vm.prank(strategist);
    _eolStrategyExecutor.settleExtraRewards(address(reward), 100 ether);

    assertEq(reward.balanceOf(address(_eolStrategyExecutor)), 0);
    assertEq(reward.balanceOf(address(_mitosisVault)), 100 ether);
  }

  function test_settleExtraRewards_Paused() public {
    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(reward));

    reward.mint(address(_eolStrategyExecutor), 100 ether);

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.settleExtraRewards.selector));
    _eolStrategyExecutor.settleExtraRewards(address(reward), 100 ether);

    vm.stopPrank();
  }

  function test_settleExtraRewards_Unauthorized() public {
    MockERC20TWABSnapshots reward = new MockERC20TWABSnapshots();
    reward.initialize(address(_delegationRegistry), 'Reward', 'REWARD');

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.initializeAsset(address(reward));

    reward.mint(address(_eolStrategyExecutor), 100 ether);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.settleExtraRewards(address(reward), 100 ether);
  }

  function test_settleExtraRewards_InvalidAddress() public {
    _token.mint(address(_eolStrategyExecutor), 100 ether);

    vm.startPrank(strategist);

    vm.expectRevert(_errInvalidAddress('reward'));
    _eolStrategyExecutor.settleExtraRewards(address(_token), 100 ether);

    vm.stopPrank();
  }

  function test_execute() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));
    MockStrategy strategy2 = new MockStrategy(address(_token));

    vm.startPrank(owner);
    uint256 strategyId1 = _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    uint256 strategyId2 = _eolStrategyExecutor.addStrategy(1, address(strategy2), '');
    _eolStrategyExecutor.enableStrategy(strategyId1);
    _eolStrategyExecutor.enableStrategy(strategyId2);
    vm.stopPrank();

    bytes[] memory strategy1_callData = new bytes[](2);
    strategy1_callData[0] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 100 ether, ''));
    strategy1_callData[1] = (abi.encodeWithSelector(MockStrategy.withdraw.selector, 250 ether, ''));

    bytes[] memory strategy2_callData = new bytes[](3);
    strategy2_callData[0] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 55 ether, ''));
    strategy2_callData[1] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 105 ether, ''));
    strategy2_callData[2] = (abi.encodeWithSelector(MockStrategy.withdraw.selector, 30 ether, ''));

    IEOLStrategyExecutor.Call[] memory calls = new IEOLStrategyExecutor.Call[](2);
    calls[0] = IEOLStrategyExecutor.Call(strategyId1, strategy1_callData);
    calls[1] = IEOLStrategyExecutor.Call(strategyId2, strategy2_callData);

    vm.startPrank(strategist);

    vm.expectCall(address(strategy1), abi.encodeWithSelector(MockStrategy.deposit.selector, 100 ether, ''));
    vm.expectCall(address(strategy1), abi.encodeWithSelector(MockStrategy.withdraw.selector, 250 ether, ''));
    vm.expectCall(address(strategy2), abi.encodeWithSelector(MockStrategy.deposit.selector, 55 ether, ''));
    vm.expectCall(address(strategy2), abi.encodeWithSelector(MockStrategy.deposit.selector, 105 ether, ''));
    vm.expectCall(address(strategy2), abi.encodeWithSelector(MockStrategy.withdraw.selector, 30 ether, ''));
    _eolStrategyExecutor.execute(calls);

    vm.stopPrank();
  }

  function test_execute_Paused() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));

    vm.startPrank(owner);
    uint256 strategyId1 = _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.enableStrategy(strategyId1);
    vm.stopPrank();

    bytes[] memory strategy1_callData = new bytes[](2);
    strategy1_callData[0] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 100 ether, ''));
    strategy1_callData[1] = (abi.encodeWithSelector(MockStrategy.withdraw.selector, 250 ether, ''));

    IEOLStrategyExecutor.Call[] memory calls = new IEOLStrategyExecutor.Call[](2);
    calls[0] = IEOLStrategyExecutor.Call(strategyId1, strategy1_callData);

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.startPrank(strategist);

    vm.expectRevert(_errPaused(EOLStrategyExecutor.execute.selector));
    _eolStrategyExecutor.execute(calls);

    vm.stopPrank();
  }

  function test_execute_Unauthorized() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));

    vm.startPrank(owner);
    uint256 strategyId1 = _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    _eolStrategyExecutor.enableStrategy(strategyId1);
    vm.stopPrank();

    bytes[] memory strategy1_callData = new bytes[](2);
    strategy1_callData[0] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 100 ether, ''));
    strategy1_callData[1] = (abi.encodeWithSelector(MockStrategy.withdraw.selector, 250 ether, ''));

    IEOLStrategyExecutor.Call[] memory calls = new IEOLStrategyExecutor.Call[](2);
    calls[0] = IEOLStrategyExecutor.Call(strategyId1, strategy1_callData);

    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.execute(calls);
  }

  function test_execute_StrategyNotEnabled() public {
    MockStrategy strategy1 = new MockStrategy(address(_token));

    vm.startPrank(owner);
    uint256 strategyId1 = _eolStrategyExecutor.addStrategy(1, address(strategy1), '');
    // _eolStrategyExecutor.enableStrategy(strategyId1);
    vm.stopPrank();

    bytes[] memory strategy1_callData = new bytes[](2);
    strategy1_callData[0] = (abi.encodeWithSelector(MockStrategy.deposit.selector, 100 ether, ''));
    strategy1_callData[1] = (abi.encodeWithSelector(MockStrategy.withdraw.selector, 250 ether, ''));

    IEOLStrategyExecutor.Call[] memory calls = new IEOLStrategyExecutor.Call[](2);
    calls[0] = IEOLStrategyExecutor.Call(strategyId1, strategy1_callData);

    vm.startPrank(strategist);

    vm.expectRevert(_errStrategyNotEnabled(strategyId1));
    _eolStrategyExecutor.execute(calls);

    vm.stopPrank();
  }

  function test_addStrategy() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(0));

    vm.prank(owner);
    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    assertEq(_eolStrategyExecutor.getStrategy(strategyId).implementation, address(strategy));
    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(strategy));
  }

  function test_addStrategy_paused() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(0));

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    vm.prank(owner);
    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    assertEq(_eolStrategyExecutor.getStrategy(strategyId).implementation, address(strategy));
    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(strategy));
  }

  function test_addStrategy_Unauthorized() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(0));

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.addStrategy(0, address(strategy), '');
  }

  function test_addStrategy_InvalidAddress() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidAddress('implementation'));
    _eolStrategyExecutor.addStrategy(0, address(0), '');

    vm.stopPrank();
  }

  function test_addStrategy_StrategyAlreadySet() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(0));

    vm.prank(owner);
    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    assertEq(_eolStrategyExecutor.getStrategy(strategyId).implementation, address(strategy));
    assertEq(_eolStrategyExecutor.getStrategy(address(strategy)).implementation, address(strategy));

    vm.startPrank(owner);

    vm.expectRevert(_errStrategyAlreadySet(address(strategy), strategyId));
    _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    vm.expectRevert(_errStrategyAlreadySet(address(strategy), strategyId));
    _eolStrategyExecutor.addStrategy(100, address(strategy), '');

    vm.expectRevert(_errStrategyAlreadySet(address(strategy), strategyId));
    _eolStrategyExecutor.addStrategy(0, address(strategy), 'Test');

    vm.stopPrank();
  }

  function test_enableStrategy() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.prank(owner);
    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    // Default: disabled
    assertFalse(_eolStrategyExecutor.isStrategyEnabled(strategyId));
    assertFalse(_eolStrategyExecutor.isStrategyEnabled(address(strategy)));

    vm.prank(owner);
    _eolStrategyExecutor.enableStrategy(strategyId);

    assertTrue(_eolStrategyExecutor.isStrategyEnabled(strategyId));
    assertTrue(_eolStrategyExecutor.isStrategyEnabled(address(strategy)));
  }

  function test_enableStrategy_Unauthorized() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.prank(owner);
    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.enableStrategy(strategyId);
  }

  function test_enableStrategy_StrategyAlreadyEnabled() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.startPrank(owner);

    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');
    _eolStrategyExecutor.enableStrategy(strategyId);

    vm.expectRevert(_errStrategyAlreadyEnabled(strategyId));
    _eolStrategyExecutor.enableStrategy(strategyId);

    vm.stopPrank();
  }

  function test_disableStrategy() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.startPrank(owner);

    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');
    _eolStrategyExecutor.enableStrategy(strategyId);

    vm.stopPrank();

    assertTrue(_eolStrategyExecutor.isStrategyEnabled(strategyId));

    vm.prank(owner);
    _eolStrategyExecutor.disableStrategy(strategyId);

    assertFalse(_eolStrategyExecutor.isStrategyEnabled(strategyId));
  }

  function test_disableStrategy_Unauthorized() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.startPrank(owner);

    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');
    _eolStrategyExecutor.enableStrategy(strategyId);

    vm.stopPrank();

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.disableStrategy(strategyId);
  }

  function test_disableStrategy_StrategyNotEnabled() public {
    MockStrategy strategy = new MockStrategy(address(_token));

    vm.startPrank(owner);

    uint256 strategyId = _eolStrategyExecutor.addStrategy(0, address(strategy), '');

    vm.expectRevert(_errStrategyNotEnabled(strategyId));
    _eolStrategyExecutor.disableStrategy(strategyId);

    _eolStrategyExecutor.enableStrategy(strategyId);

    vm.stopPrank();

    assertTrue(_eolStrategyExecutor.isStrategyEnabled(strategyId));

    vm.startPrank(owner);

    _eolStrategyExecutor.disableStrategy(strategyId);
    assertFalse(_eolStrategyExecutor.isStrategyEnabled(strategyId));

    vm.expectRevert(_errStrategyNotEnabled(strategyId));
    _eolStrategyExecutor.disableStrategy(strategyId);

    vm.stopPrank();
  }

  function tset_setEmergencyManager() public {
    address newEmergencyManager = makeAddr('newEmergencyManager');

    assertEq(_eolStrategyExecutor.emergencyManager(), owner);

    vm.prank(owner);
    _eolStrategyExecutor.setEmergencyManager(newEmergencyManager);

    assertEq(_eolStrategyExecutor.emergencyManager(), newEmergencyManager);
  }

  function tset_setEmergencyManager_Unauthorized() public {
    address newEmergencyManager = makeAddr('newEmergencyManager');

    assertEq(_eolStrategyExecutor.emergencyManager(), owner);

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.setEmergencyManager(newEmergencyManager);
  }

  function tset_setEmergencyManager_InvalidAddress() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidAddress('emergencyManager'));
    _eolStrategyExecutor.setEmergencyManager(address(0));

    vm.stopPrank();
  }

  function test_setStrategist() public {
    address newStrategist = makeAddr('newStrategist');

    assertEq(_eolStrategyExecutor.strategist(), strategist);

    vm.prank(owner);
    _eolStrategyExecutor.setStrategist(newStrategist);

    assertEq(_eolStrategyExecutor.strategist(), newStrategist);
  }

  function test_setStrategist_Unauthorized() public {
    address newStrategist = makeAddr('newStrategist');

    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.setStrategist(newStrategist);
  }

  function test_setStrategist_InvalidAddress() public {
    vm.startPrank(owner);

    vm.expectRevert(_errInvalidAddress('strategist'));
    _eolStrategyExecutor.setStrategist(address(0));

    vm.stopPrank();
  }

  function test_unsetStrategist() public {
    assertEq(_eolStrategyExecutor.strategist(), strategist);

    vm.prank(owner);
    _eolStrategyExecutor.unsetStrategist();

    assertEq(_eolStrategyExecutor.strategist(), address(0));
  }

  function test_unsetStrategist_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.unsetStrategist();
  }

  function test_pause() public {
    assertFalse(_eolStrategyExecutor.isPausedGlobally());

    vm.prank(emergencyManager);
    _eolStrategyExecutor.pause();

    assertTrue(_eolStrategyExecutor.isPausedGlobally());
  }

  function test_pause_owner() public {
    vm.prank(owner);

    assertFalse(_eolStrategyExecutor.isPausedGlobally());

    vm.prank(owner);
    _eolStrategyExecutor.pause();

    assertTrue(_eolStrategyExecutor.isPausedGlobally());
  }

  function test_pause_Unauthorized() public {
    vm.expectRevert(StdError.Unauthorized.selector);
    _eolStrategyExecutor.pause();
  }

  function test_unpause() public {
    test_pause();
    assertTrue(_eolStrategyExecutor.isPausedGlobally());

    vm.prank(owner);
    _eolStrategyExecutor.unpause();

    assertFalse(_eolStrategyExecutor.isPausedGlobally());
  }

  function test_unpause_emergencyManager() public {
    test_pause();
    assertTrue(_eolStrategyExecutor.isPausedGlobally());

    vm.startPrank(emergencyManager);

    vm.expectRevert(_errOwnableUnauthorizedAccount(emergencyManager));
    _eolStrategyExecutor.unpause();

    vm.stopPrank();
  }

  function test_unpause_Unauthorized() public {
    vm.expectRevert(_errOwnableUnauthorizedAccount(address(this)));
    _eolStrategyExecutor.unpause();
  }

  function _allocateEOL(uint256 amount) internal {
    _token.mint(address(_mitosisVault), amount);

    uint256 prevAvailableEOL = _mitosisVault.availableEOL(hubEOLVault);

    vm.prank(address(_mitosisVaultEntrypoint));
    _mitosisVault.allocateEOL(hubEOLVault, amount);

    assertEq(_mitosisVault.availableEOL(hubEOLVault), prevAvailableEOL + amount);
  }

  function _fetchEOL(uint256 amount) internal {
    uint256 prevstoredTotalBalance = _eolStrategyExecutor.storedTotalBalance();
    uint256 prevBalance = _token.balanceOf(address(_eolStrategyExecutor));
    uint256 prevAvailableEOL = _mitosisVault.availableEOL(hubEOLVault);

    vm.prank(strategist);
    _eolStrategyExecutor.fetchEOL(amount);

    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), prevBalance + amount);
    assertEq(_eolStrategyExecutor.storedTotalBalance(), prevstoredTotalBalance + amount);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), prevAvailableEOL - amount);
  }

  function _returnEOL(uint256 amount) internal {
    uint256 prevstoredTotalBalance = _eolStrategyExecutor.storedTotalBalance();
    uint256 prevBalance = _token.balanceOf(address(_eolStrategyExecutor));
    uint256 prevAvailableEOL = _mitosisVault.availableEOL(hubEOLVault);

    vm.prank(strategist);
    _eolStrategyExecutor.returnEOL(amount);

    assertEq(_token.balanceOf(address(_eolStrategyExecutor)), prevBalance - amount);
    assertEq(_eolStrategyExecutor.storedTotalBalance(), prevstoredTotalBalance - amount);
    assertEq(_mitosisVault.availableEOL(hubEOLVault), prevAvailableEOL + amount);
  }

  function _errStrategyNotEnabled(uint256 strategyId) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(IEOLStrategyExecutor.IEOLStrategyExecutor__StrategyNotEnabled.selector, strategyId);
  }

  function _errStrategyAlreadySet(address implementation, uint256 strategyId) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(
      IEOLStrategyExecutor.IEOLStrategyExecutor__StrategyAlreadySet.selector, implementation, strategyId
    );
  }

  function _errStrategyAlreadyEnabled(uint256 strategyId) internal pure returns (bytes memory) {
    return
      abi.encodeWithSelector(IEOLStrategyExecutor.IEOLStrategyExecutor__StrategyAlreadyEnabled.selector, strategyId);
  }
}
