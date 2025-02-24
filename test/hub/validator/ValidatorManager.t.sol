// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { stdJson } from '@std/stdJson.sol';
import { Vm } from '@std/Vm.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';

import { LibClone } from '@solady/utils/LibClone.sol';
import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/validator/EpochFeeder.sol';
import { ValidatorManager } from '../../../src/hub/validator/ValidatorManager.sol';
import { IConsensusValidatorEntrypoint } from
  '../../../src/interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/validator/IEpochFeeder.sol';
import { IValidatorManager } from '../../../src/interfaces/hub/validator/IValidatorManager.sol';
import { LibSecp256k1 } from '../../../src/lib/LibSecp256k1.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorManagerTest is Toolkit {
  using SafeCast for uint256;
  using stdJson for string;
  using LibSecp256k1 for bytes;
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
  ValidatorManager manager;

  function setUp() public {
    entrypoint = new MockContract();

    epochFeeder = EpochFeeder(
      _proxy(
        address(new EpochFeeder()), //
        abi.encodeCall(EpochFeeder.initialize, (owner, block.timestamp + epochInterval, epochInterval))
      )
    );
    manager = ValidatorManager(
      _proxy(
        address(new ValidatorManager()),
        abi.encodeCall(
          ValidatorManager.initialize,
          (
            owner,
            epochFeeder,
            IConsensusValidatorEntrypoint(address(entrypoint)),
            IValidatorManager.SetGlobalValidatorConfigRequest({
              initialValidatorDeposit: 1000 ether,
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
    assertEq(manager.owner(), owner);
    assertEq(address(manager.epochFeeder()), address(epochFeeder));
    assertEq(address(manager.entrypoint()), address(entrypoint));

    IValidatorManager.GlobalValidatorConfigResponse memory config = manager.globalValidatorConfig();
    assertEq(config.initialValidatorDeposit, 1000 ether);
    assertEq(config.collateralWithdrawalDelay, 1000 seconds);
    assertEq(config.minimumCommissionRate, 100);
    assertEq(config.commissionRateUpdateDelay, 3);

    assertEq(manager.validatorCount(), 0);
  }

  function test_createValidator(string memory name) public returns (ValidatorKey memory) {
    ValidatorKey memory val = _makeValKey(name);
    vm.deal(val.addr, 1000 ether);

    bytes memory metadata = _buildMetadata(name, 'test-val', 'test validator of mitosis');

    uint256 nextIndex = manager.validatorCount();

    vm.prank(val.addr);
    manager.createValidator{ value: 1000 ether }(
      LibSecp256k1.compressPubkey(val.pubKey),
      IValidatorManager.CreateValidatorRequest({ commissionRate: 100, metadata: metadata })
    );

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.registerValidator.selector,
      abi.encode(LibSecp256k1.compressPubkey(val.pubKey), val.addr),
      1000 ether
    );

    assertEq(manager.validatorCount(), nextIndex + 1);
    assertEq(manager.validatorAt(nextIndex), val.addr);
    assertTrue(manager.isValidator(val.addr));

    IValidatorManager.ValidatorInfoResponse memory info = manager.validatorInfo(val.addr);
    assertEq(info.valAddr, val.addr);
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
    manager.updateOperator(val.pubKey.compressPubkey(), operator);

    vm.deal(operator, 1000 ether);
    vm.prank(operator);
    manager.depositCollateral{ value: 1000 ether }(val.pubKey.compressPubkey());

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.depositCollateral.selector, abi.encode(val.pubKey.compressPubkey()), 1000 ether
    );
  }

  function test_withdrawCollateral() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');
    address recipient = makeAddr('recipient');

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), operator);

    vm.prank(operator);
    manager.withdrawCollateral(val.pubKey.compressPubkey(), recipient, 1000 ether);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.withdrawCollateral.selector,
      abi.encode(LibSecp256k1.compressPubkey(val.pubKey), 1000 ether, recipient, block.timestamp + 1000 seconds)
    );
  }

  function test_unjailValidator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), operator);

    vm.prank(operator);
    manager.unjailValidator(val.pubKey.compressPubkey());

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.unjail.selector, abi.encode(LibSecp256k1.compressPubkey(val.pubKey))
    );
  }

  function test_updateOperator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), newOperator);

    assertEq(manager.validatorInfo(val.addr).operator, newOperator);
  }

  function test_updateRewardRecipient() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    address newRecipient = makeAddr('newRecipient');

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), newOperator);

    vm.prank(newOperator);
    manager.updateRewardRecipient(val.pubKey.compressPubkey(), newRecipient);

    assertEq(manager.validatorInfo(val.addr).rewardRecipient, newRecipient);
  }

  function test_updateMetadata() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    bytes memory newMetadata = _buildMetadata('val-2', 'test-val-2', 'test validator of mitosis-2');

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), newOperator);

    vm.prank(newOperator);
    manager.updateMetadata(val.pubKey.compressPubkey(), newMetadata);

    assertEq(manager.validatorInfo(val.addr).metadata, newMetadata);
  }

  function test_updateRewardConfig() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    uint256 newCommissionRate = 200;

    vm.prank(val.addr);
    manager.updateOperator(val.pubKey.compressPubkey(), newOperator);

    vm.prank(newOperator);
    manager.updateRewardConfig(
      val.pubKey.compressPubkey(), IValidatorManager.UpdateRewardConfigRequest({ commissionRate: newCommissionRate })
    );

    assertEq(manager.validatorInfo(val.addr).commissionRate, newCommissionRate);
  }

  // function test_stake() public returns (ValidatorKey memory) {
  //   address staker = makeAddr('staker');
  //   ValidatorKey memory val = test_createValidator('val-1');

  //   vm.deal(staker, 500 ether);
  //   vm.prank(staker);
  //   manager.stake{ value: 500 ether }(val.addr, staker);

  //   assertEq(manager.totalStaked(), 500 ether);
  //   assertEq(manager.totalUnstaking(), 0 ether);

  //   assertEq(manager.staked(val.addr, staker), 500 ether);
  //   assertEq(manager.totalDelegation(val.addr), 500 ether);

  //   // no time has passed
  //   assertEq(manager.stakedTWAB(val.addr, staker), 0);
  //   assertEq(manager.totalDelegationTWAB(val.addr), 0);

  //   // 1 second has passed - must be the same with the current staked amount
  //   uint48 now_ = epochFeeder.clock();
  //   assertEq(manager.stakedTWABAt(val.addr, staker, now_ + 3), 500 ether * 3);
  //   assertEq(manager.totalDelegationTWABAt(val.addr, now_ + 3), 500 ether * 3);

  //   return val;
  // }

  // function test_unstake() public {
  //   address staker = makeAddr('staker');
  //   ValidatorKey memory val = test_createValidator('val-1');

  //   vm.deal(staker, 500 ether);
  //   vm.prank(staker);
  //   manager.stake{ value: 500 ether }(val.addr, staker);

  //   vm.prank(staker);
  //   manager.requestUnstake(val.addr, staker, 500 ether);

  //   assertEq(manager.staked(val.addr, staker), 0);
  //   assertEq(manager.totalStaked(), 0);
  //   assertEq(manager.totalUnstaking(), 500 ether);
  //   assertEq(manager.totalDelegation(val.addr), 0);

  //   {
  //     (uint256 claimable, uint256 nonClaimable) = manager.unstaking(val.addr, staker);
  //     assertEq(claimable, 0);
  //     assertEq(nonClaimable, 500 ether);
  //   }

  //   vm.warp(block.timestamp + manager.globalValidatorConfig().unstakeCooldown + 1);

  //   {
  //     (uint256 claimable, uint256 nonClaimable) = manager.unstaking(val.addr, staker);
  //     assertEq(claimable, 500 ether);
  //     assertEq(nonClaimable, 0);
  //   }

  //   vm.prank(staker);
  //   uint256 claimAmount = manager.claimUnstake(val.addr, staker);

  //   assertEq(claimAmount, 500 ether);
  //   {
  //     (uint256 claimable, uint256 nonClaimable) = manager.unstaking(val.addr, staker);
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
  //   manager.stake{ value: 500 ether }(val1.addr, staker);
  //   manager.redelegate(val1.addr, val2.addr, 250 ether);
  //   vm.stopPrank();

  //   assertEq(manager.totalStaked(), 500 ether);
  //   assertEq(manager.staked(val1.addr, staker), 250 ether);
  //   assertEq(manager.staked(val2.addr, staker), 250 ether);
  //   assertEq(manager.totalDelegation(val1.addr), 250 ether);
  //   assertEq(manager.totalDelegation(val2.addr), 250 ether);
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
