// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';
import { stdJson } from '@std/StdJson.sol';
import { Vm } from '@std/Vm.sol';

import { ERC1967Proxy } from '@oz-v5/proxy/ERC1967/ERC1967Proxy.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

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
        abi.encodeCall(
          EpochFeeder.initialize, (owner, Time.timestamp() + epochInterval.toUint48(), epochInterval.toUint48())
        )
      )
    );

    IValidatorManager.GenesisValidatorSet[] memory genesisValidators = new IValidatorManager.GenesisValidatorSet[](0);
    manager = ValidatorManager(
      _proxy(
        address(new ValidatorManager(epochFeeder, IConsensusValidatorEntrypoint(address(entrypoint)))),
        abi.encodeCall(
          ValidatorManager.initialize,
          (
            owner,
            0,
            IValidatorManager.SetGlobalValidatorConfigRequest({
              initialValidatorDeposit: 1000 ether,
              collateralWithdrawalDelay: 1000 seconds,
              minimumCommissionRate: 100, // 1 %
              commissionRateUpdateDelay: 3 // 3 * 100 seconds
             }),
            genesisValidators
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
    ValidatorKey memory val = _makePubKey(name);
    vm.deal(val.addr, 1000 ether);

    bytes memory metadata = _buildMetadata(name, 'test-val', 'test validator of mitosis');

    uint256 validatorCount = manager.validatorCount();

    vm.prank(val.addr);
    manager.createValidator{ value: 1000 ether }(
      LibSecp256k1.compressPubkey(val.pubKey),
      IValidatorManager.CreateValidatorRequest({
        operator: val.addr,
        withdrawalRecipient: val.addr,
        rewardRecipient: val.addr,
        commissionRate: 100,
        metadata: metadata
      })
    );

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.registerValidator.selector,
      abi.encode(val.addr, LibSecp256k1.compressPubkey(val.pubKey), val.addr),
      1000 ether
    );

    assertEq(manager.validatorCount(), validatorCount + 1);
    assertEq(manager.validatorAt(validatorCount + 1), val.addr);
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
    address withdrawalRecipient = makeAddr('withdrawalRecipient');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, operator);
    vm.prank(operator);
    manager.updateWithdrawalRecipient(val.addr, withdrawalRecipient);

    vm.deal(operator, 1000 ether);
    vm.prank(operator);
    manager.depositCollateral{ value: 1000 ether }(val.addr);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.depositCollateral.selector, abi.encode(val.addr, withdrawalRecipient), 1000 ether
    );
  }

  function test_withdrawCollateral() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');
    address withdrawalRecipient = makeAddr('withdrawalRecipient');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, operator);
    vm.prank(operator);
    manager.updateWithdrawalRecipient(val.addr, withdrawalRecipient);

    vm.prank(operator);
    manager.withdrawCollateral(val.addr, 1000 ether);

    entrypoint.assertLastCall(
      IConsensusValidatorEntrypoint.withdrawCollateral.selector,
      abi.encode(val.addr, 1000 ether, withdrawalRecipient, block.timestamp + 1000 seconds)
    );
  }

  function test_unjailValidator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address operator = makeAddr('operator');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, operator);

    vm.prank(operator);
    manager.unjailValidator(val.addr);

    entrypoint.assertLastCall(IConsensusValidatorEntrypoint.unjail.selector, abi.encode(val.addr));
  }

  function test_updateOperator() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, newOperator);

    assertEq(manager.validatorInfo(val.addr).operator, newOperator);
  }

  function test_updateRewardRecipient() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    address newRecipient = makeAddr('newRecipient');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, newOperator);

    vm.prank(newOperator);
    manager.updateRewardRecipient(val.addr, newRecipient);

    assertEq(manager.validatorInfo(val.addr).rewardRecipient, newRecipient);
  }

  function test_updateMetadata() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    bytes memory newMetadata = _buildMetadata('val-2', 'test-val-2', 'test validator of mitosis-2');

    vm.prank(val.addr);
    manager.updateOperator(val.addr, newOperator);

    vm.prank(newOperator);
    manager.updateMetadata(val.addr, newMetadata);

    assertEq(manager.validatorInfo(val.addr).metadata, newMetadata);
  }

  function test_updateRewardConfig() public {
    ValidatorKey memory val = test_createValidator('val-1');
    address newOperator = makeAddr('newOperator');
    uint256 newCommissionRate = 200;

    vm.prank(val.addr);
    manager.updateOperator(val.addr, newOperator);

    vm.prank(newOperator);
    manager.updateRewardConfig(
      val.addr, IValidatorManager.UpdateRewardConfigRequest({ commissionRate: newCommissionRate })
    );

    assertEq(manager.validatorInfo(val.addr).commissionRate, newCommissionRate);
  }

  function _makePubKey(string memory name) internal returns (ValidatorKey memory) {
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
