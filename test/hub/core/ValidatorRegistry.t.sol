// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { stdJson } from '@std/stdJson.sol';
import { Vm } from '@std/Vm.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/core/EpochFeeder.sol';
import { ValidatorRegistry } from '../../../src/hub/core/ValidatorRegistry.sol';
import { IConsensusValidatorEntrypoint } from
  '../../../src/interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/core/IEpochFeeder.sol';
import { IValidatorRegistry } from '../../../src/interfaces/hub/core/IValidatorRegistry.sol';
import { LibSecp256k1 } from '../../../src/lib/LibSecp256k1.sol';
import { Toolkit } from '../../util/Toolkit.sol';
import { MockContract } from '../../util/MockContract.sol';

contract ValidatorManagerTest is Toolkit {
  using SafeCast for uint256;
  using stdJson for string;
  using LibString for *;

  struct ValidatorKey {
    address addr;
    uint256 privKey;
    bytes pubKey; // uncompressed
  }

  address owner = makeAddr('owner');
  uint256 jsonNonce = 0;
  uint256 epochInterval = 100 seconds;

  MockContract entrypoint;
  EpochFeeder epochFeeder;
  ValidatorRegistry registry;

  function setUp() public {
    entrypoint = new MockContract();

    epochFeeder = EpochFeeder(
      _proxy(
        address(new EpochFeeder()), //
        abi.encodeCall(EpochFeeder.initialize, (owner, block.timestamp + epochInterval, epochInterval))
      )
    );
    registry = ValidatorRegistry(
      _proxy(
        address(new ValidatorRegistry()),
        abi.encodeCall(
          ValidatorRegistry.initialize,
          (
            owner,
            epochFeeder,
            IConsensusValidatorEntrypoint(address(entrypoint)),
            IValidatorRegistry.SetGlobalValidatorConfigRequest({
              initialValidatorDeposit: 1000 ether,
              unstakeCooldown: 1000 seconds,
              redelegationCooldown: 1000 seconds,
              collateralWithdrawalDelay: 1000 seconds,
              minimumCommissionRate: 100, // 1 %
              commissionRateUpdateDelay: 3 // 3 * 100 seconds
             })
          )
        )
      )
    );
  }

  function test_init() public view {
    assertEq(registry.owner(), owner);
    assertEq(address(registry.epochFeeder()), address(epochFeeder));
    assertEq(address(registry.entrypoint()), address(entrypoint));

    IValidatorRegistry.GlobalValidatorConfigResponse memory config = registry.globalValidatorConfig();
    assertEq(config.initialValidatorDeposit, 1000 ether);
    assertEq(config.unstakeCooldown, 1000 seconds);
    assertEq(config.collateralWithdrawalDelay, 1000 seconds);
    assertEq(config.minimumCommissionRate, 100);
    assertEq(config.commissionRateUpdateDelay, 3);

    assertEq(registry.validatorCount(), 0);
  }

  function test_createValidator(string memory name) public returns (ValidatorKey memory) {
    ValidatorKey memory val = _makeValKey(name);
    vm.deal(val.addr, 1000 ether);

    bytes memory metadata = _buildMetadata(name, 'test-val', 'test validator of mitosis');

    uint256 nextIndex = registry.validatorCount();

    vm.prank(val.addr);
    registry.createValidator{ value: 1000 ether }(
      LibSecp256k1.compressPubkey(val.pubKey),
      IValidatorRegistry.CreateValidatorRequest({ commissionRate: 100, metadata: metadata })
    );

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.registerValidator.selector,
      abi.encode(LibSecp256k1.compressPubkey(val.pubKey), val.addr),
      1000 ether
    );

    assertEq(registry.validatorCount(), nextIndex + 1);
    assertEq(registry.validatorAt(nextIndex), val.addr);
    assertTrue(registry.isValidator(val.addr));

    IValidatorRegistry.ValidatorInfoResponse memory info = registry.validatorInfo(val.addr);
    assertEq(info.validator, val.addr);
    assertEq(info.operator, val.addr);
    assertEq(info.rewardRecipient, val.addr);
    assertEq(info.commissionRate, 100);
    assertEq(info.metadata, metadata);

    return val;
  }

  function test_depositCollateral() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');

    vm.prank(val.addr);
    registry.updateOperator(operator);

    vm.deal(operator, 1000 ether);
    vm.prank(operator);
    registry.depositCollateral{ value: 1000 ether }(val.addr);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.depositCollateral.selector,
      abi.encode(LibSecp256k1.compressPubkey(val.pubKey)),
      1000 ether
    );
  }

  function test_withdrawCollateral() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');
    address recipient = makeAddr('recipient');

    vm.prank(val.addr);
    registry.updateOperator(operator);

    vm.prank(operator);
    registry.withdrawCollateral(val.addr, recipient, 1000 ether);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.withdrawCollateral.selector,
      abi.encode(LibSecp256k1.compressPubkey(val.pubKey), 1000 ether, recipient, block.timestamp + 1000 seconds)
    );
  }

  function test_unjailValidator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');

    vm.prank(val.addr);
    registry.updateOperator(operator);

    vm.prank(operator);
    registry.unjailValidator(val.addr);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.unjail.selector, abi.encode(LibSecp256k1.compressPubkey(val.pubKey))
    );
  }

  function test_updateOperator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');

    vm.prank(val.addr);
    registry.updateOperator(newOperator);

    assertEq(registry.validatorInfo(val.addr).operator, newOperator);
  }

  function test_updateRewardRecipient() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    address newRecipient = makeAddr('newRecipient');

    vm.prank(val.addr);
    registry.updateOperator(newOperator);

    vm.prank(newOperator);
    registry.updateRewardRecipient(val.addr, newRecipient);

    assertEq(registry.validatorInfo(val.addr).rewardRecipient, newRecipient);
  }

  function test_updateMetadata() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    bytes memory newMetadata = _buildMetadata('val-2', 'test-val-2', 'test validator of mitosis-2');

    vm.prank(val.addr);
    registry.updateOperator(newOperator);

    vm.prank(newOperator);
    registry.updateMetadata(val.addr, newMetadata);

    assertEq(registry.validatorInfo(val.addr).metadata, newMetadata);
  }

  function test_updateRewardConfig() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    uint256 newCommissionRate = 200;

    vm.prank(val.addr);
    registry.updateOperator(newOperator);

    vm.prank(newOperator);
    registry.updateRewardConfig(
      val.addr, IValidatorRegistry.UpdateRewardConfigRequest({ commissionRate: newCommissionRate })
    );

    assertEq(registry.validatorInfo(val.addr).commissionRate, newCommissionRate);
  }

  // function test_stake() public returns (ValidatorKey memory) {
  //   address staker = makeAddr('staker');
  //   ValidatorKey memory val = test_createValidator('val-1');

  //   vm.deal(staker, 500 ether);
  //   vm.prank(staker);
  //   registry.stake{ value: 500 ether }(val.addr, staker);

  //   assertEq(registry.totalStaked(), 500 ether);
  //   assertEq(registry.totalUnstaking(), 0 ether);

  //   assertEq(registry.staked(val.addr, staker), 500 ether);
  //   assertEq(registry.totalDelegation(val.addr), 500 ether);

  //   // no time has passed
  //   assertEq(registry.stakedTWAB(val.addr, staker), 0);
  //   assertEq(registry.totalDelegationTWAB(val.addr), 0);

  //   // 1 second has passed - must be the same with the current staked amount
  //   uint48 now_ = epochFeeder.clock();
  //   assertEq(registry.stakedTWABAt(val.addr, staker, now_ + 3), 500 ether * 3);
  //   assertEq(registry.totalDelegationTWABAt(val.addr, now_ + 3), 500 ether * 3);

  //   return val;
  // }

  // function test_unstake() public {
  //   address staker = makeAddr('staker');
  //   ValidatorKey memory val = test_createValidator('val-1');

  //   vm.deal(staker, 500 ether);
  //   vm.prank(staker);
  //   registry.stake{ value: 500 ether }(val.addr, staker);

  //   vm.prank(staker);
  //   registry.requestUnstake(val.addr, staker, 500 ether);

  //   assertEq(registry.staked(val.addr, staker), 0);
  //   assertEq(registry.totalStaked(), 0);
  //   assertEq(registry.totalUnstaking(), 500 ether);
  //   assertEq(registry.totalDelegation(val.addr), 0);

  //   {
  //     (uint256 claimable, uint256 nonClaimable) = registry.unstaking(val.addr, staker);
  //     assertEq(claimable, 0);
  //     assertEq(nonClaimable, 500 ether);
  //   }

  //   vm.warp(block.timestamp + registry.globalValidatorConfig().unstakeCooldown + 1);

  //   {
  //     (uint256 claimable, uint256 nonClaimable) = registry.unstaking(val.addr, staker);
  //     assertEq(claimable, 500 ether);
  //     assertEq(nonClaimable, 0);
  //   }

  //   vm.prank(staker);
  //   uint256 claimAmount = registry.claimUnstake(val.addr, staker);

  //   assertEq(claimAmount, 500 ether);
  //   {
  //     (uint256 claimable, uint256 nonClaimable) = registry.unstaking(val.addr, staker);
  //     assertEq(claimable, 0);
  //     assertEq(nonClaimable, 0);
  //   }

  //   assertEq(staker.balance, 500 ether);
  // }

  // function test_redelegate() public {
  //   address staker = makeAddr('staker');
  //   ValidatorKey memory val1 = test_createValidator('val-1');
  //   ValidatorKey memory val2 = test_createValidator('val-2');

  //   vm.deal(staker, 500 ether);
  //   vm.startPrank(staker);
  //   registry.stake{ value: 500 ether }(val1.addr, staker);
  //   registry.redelegate(val1.addr, val2.addr, 250 ether);
  //   vm.stopPrank();

  //   assertEq(registry.totalStaked(), 500 ether);
  //   assertEq(registry.staked(val1.addr, staker), 250 ether);
  //   assertEq(registry.staked(val2.addr, staker), 250 ether);
  //   assertEq(registry.totalDelegation(val1.addr), 250 ether);
  //   assertEq(registry.totalDelegation(val2.addr), 250 ether);
  // }

  function _makeValKey(string memory name) internal returns (ValidatorKey memory) {
    (address addr, uint256 privKey) = makeAddrAndKey(name);
    Vm.Wallet memory wallet = vm.createWallet(privKey);
    bytes memory pubKey = abi.encodePacked(hex'04', wallet.publicKeyX, wallet.publicKeyY);

    // verify
    LibSecp256k1.verifyUncmpPubkey(pubKey);
    LibSecp256k1.verifyUncmpPubkeyWithAddress(pubKey, addr);

    return ValidatorKey({ addr: addr, privKey: privKey, pubKey: pubKey });
  }

  function _buildMetadata(string memory name, string memory moniker, string memory description)
    internal
    returns (bytes memory)
  {
    string memory key = string.concat('metadata', (jsonNonce++).toString());
    string memory out;

    out = key.serialize('name', name);
    out = key.serialize('moniker', moniker);
    out = key.serialize('description', description);
    out = key.serialize('website', string('https://mitosis.org'));
    out = key.serialize('image_url', string('https://picsum.photos/200/300'));

    return bytes(out);
  }
}
