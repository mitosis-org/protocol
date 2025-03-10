// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from '@oz-v5/interfaces/IERC20.sol';
import { SafeCast } from '@oz-v5/utils/math/SafeCast.sol';
import { Time } from '@oz-v5/utils/types/Time.sol';

import { LibString } from '@solady/utils/LibString.sol';

import { EpochFeeder } from '../../../src/hub/validator/EpochFeeder.sol';
import { ValidatorRewardDistributor } from '../../../src/hub/validator/ValidatorRewardDistributor.sol';
import { ValidatorStakingHub } from '../../../src/hub/validator/ValidatorStakingHub.sol';
import { IConsensusValidatorEntrypoint } from
  '../../../src/interfaces/hub/consensus-layer/IConsensusValidatorEntrypoint.sol';
import { IGovMITO } from '../../../src/interfaces/hub/IGovMITO.sol';
import { IGovMITOEmission } from '../../../src/interfaces/hub/IGovMITOEmission.sol';
import { IEpochFeeder } from '../../../src/interfaces/hub/validator/IEpochFeeder.sol';
import {
  IValidatorContributionFeed,
  ValidatorWeight
} from '../../../src/interfaces/hub/validator/IValidatorContributionFeed.sol';
import { IValidatorManager } from '../../../src/interfaces/hub/validator/IValidatorManager.sol';
import { IValidatorRewardDistributor } from '../../../src/interfaces/hub/validator/IValidatorRewardDistributor.sol';
import { IValidatorStaking } from '../../../src/interfaces/hub/validator/IValidatorStaking.sol';
import { MockContract } from '../../util/MockContract.sol';
import { Toolkit } from '../../util/Toolkit.sol';

contract ValidatorRewardDistributorTest is Toolkit {
  using SafeCast for uint256;
  using LibString for *;

  address _owner = makeAddr('owner');
  uint256 _initialTimestamp = 100;
  uint256 _epochInterval = 100 seconds;

  MockContract _govMITO;
  MockContract _govMITOEmission;
  MockContract _validatorManager;
  MockContract _epochFeed;
  MockContract _contributionFeed;
  ValidatorStakingHub _stakingHub;
  ValidatorRewardDistributor _distributor;

  uint256 snapshotId;

  function setUp() public {
    vm.warp(_initialTimestamp);

    _validatorManager = new MockContract();
    _validatorManager.setStatic(IValidatorManager.validatorInfo.selector, true);
    _validatorManager.setStatic(IValidatorManager.validatorInfoAt.selector, true);
    _validatorManager.setStatic(IValidatorManager.MAX_COMMISSION_RATE.selector, true);

    _stakingHub = ValidatorStakingHub(
      _proxy(
        address(
          new ValidatorStakingHub(
            IConsensusValidatorEntrypoint(address(new MockContract())), IValidatorManager(address(_validatorManager))
          )
        ),
        abi.encodeCall(ValidatorStakingHub.initialize, (_owner))
      )
    );

    vm.prank(_owner);
    _stakingHub.addNotifier(address(this));

    _contributionFeed = new MockContract();
    _contributionFeed.setStatic(IValidatorContributionFeed.available.selector, true);
    _contributionFeed.setStatic(IValidatorContributionFeed.weightOf.selector, true);
    _contributionFeed.setStatic(IValidatorContributionFeed.summary.selector, true);

    _govMITO = new MockContract();

    _epochFeed = new MockContract();

    _govMITOEmission = new MockContract();

    _distributor = ValidatorRewardDistributor(
      _proxy(
        address(
          new ValidatorRewardDistributor(
            address(_epochFeed),
            address(_validatorManager),
            address(_stakingHub),
            address(_contributionFeed),
            address(_govMITOEmission)
          )
        ),
        abi.encodeCall(ValidatorRewardDistributor.initialize, (_owner))
      )
    );

    snapshotId = vm.snapshot();
  }

  function test_init() public view {
    assertEq(_distributor.owner(), _owner);
    assertEq(address(_distributor.epochFeeder()), address(_epochFeed));
    assertEq(address(_distributor.validatorManager()), address(_validatorManager));
    assertEq(address(_distributor.validatorStakingHub()), address(_stakingHub));
    assertEq(address(_distributor.validatorContributionFeed()), address(_contributionFeed));
    assertEq(address(_distributor.govMITOEmission()), address(_govMITOEmission));
  }

  struct EpochParam {
    uint256 epoch;
    uint256 startsAt;
    uint256 endsAt;
    bool available;
    uint256 totalReward;
    ValidatorParam[] validatorParams;
    uint96[] validatorWeights;
    uint128[] validatorCollateralRewardShare;
    uint128[] validatorDelegationRewardShare;
  }

  struct ValidatorParam {
    address valAddr;
    address operatorAddr;
    address rewardRecipient;
    uint256 comissionRate;
    address[] stakers;
    uint256[] twabs;
  }

  function test_claim_rewards() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](1);
    validatorWeights[0] = 100;
    uint128[] memory validatorCollateralRewardShare = new uint128[](1);
    validatorCollateralRewardShare[0] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](1);
    validatorDelegationRewardShare[0] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](1);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;
    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // operator: 50, delegators: 50, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 55 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 45 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
  }

  function test_claim_rewards_by_multiple_validator() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](2);
    validatorWeights[0] = 50;
    validatorWeights[1] = 50;
    uint128[] memory validatorCollateralRewardShare = new uint128[](2);
    validatorCollateralRewardShare[0] = 80;
    validatorCollateralRewardShare[1] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](2);
    validatorDelegationRewardShare[0] = 20;
    validatorDelegationRewardShare[1] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](2);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    validatorParams[1] = ValidatorParam({
      valAddr: makeAddr('val-2'),
      operatorAddr: makeAddr('operator-2'),
      rewardRecipient: makeAddr('rewardRecipient-2'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;

    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    validatorParams[1].stakers = stakers;
    validatorParams[1].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // total reward: 100 => val-1 50, val-2 50
    // val-1: operator 80 %, delegators 20%, comission: 10%
    // val-2: operator 50 %, delegators 50%, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 41 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 9 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);

    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 27.5 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 22.5 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 0);
  }

  function test_claim_rewards_by_multiple_validator_diff_weight() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](2);
    validatorWeights[0] = 70;
    validatorWeights[1] = 30;
    uint128[] memory validatorCollateralRewardShare = new uint128[](2);
    validatorCollateralRewardShare[0] = 50;
    validatorCollateralRewardShare[1] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](2);
    validatorDelegationRewardShare[0] = 50;
    validatorDelegationRewardShare[1] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](2);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    validatorParams[1] = ValidatorParam({
      valAddr: makeAddr('val-2'),
      operatorAddr: makeAddr('operator-2'),
      rewardRecipient: makeAddr('rewardRecipient-2'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;

    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    validatorParams[1].stakers = stakers;
    validatorParams[1].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // total reward: 100 => val-1 70, val-2 30
    //
    // val-1: operator 80 %, delegators 20%, comission: 10%
    // val-2: operator 50 %, delegators 50%, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 38.5 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 31.5 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);

    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 16.5 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 13.5 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 0);
  }

  function test_claim_rewards_by_multiple_stakers() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](1);
    validatorWeights[0] = 100;
    uint128[] memory validatorCollateralRewardShare = new uint128[](1);
    validatorCollateralRewardShare[0] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](1);
    validatorDelegationRewardShare[0] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](1);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](3);
    uint256[] memory twabs = new uint256[](3);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 50;
    stakers[1] = makeAddr('staker-2');
    twabs[1] = 25;
    stakers[2] = makeAddr('staker-3');
    twabs[2] = 25;
    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // operator: 50, delegators: 50, comission: 10%
    //
    // staker1: 50%, staker2: 25%, staker3: 25%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 55 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 22.5 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-2'), makeAddr('val-1')), 11.25 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-3'), makeAddr('val-1')), 11.25 ether);

    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
  }

  function test_claim_rewards_by_diff_collateral() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](1);
    validatorWeights[0] = 100;
    uint128[] memory validatorCollateralRewardShare = new uint128[](1);
    validatorCollateralRewardShare[0] = 80;
    uint128[] memory validatorDelegationRewardShare = new uint128[](1);
    validatorDelegationRewardShare[0] = 20;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](1);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;
    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // operator: 80, delegators: 20, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 82 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 18 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
  }

  function test_claim_multiple_epoch() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](2);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });
    epochParams[1] = EpochParam({
      epoch: 2,
      startsAt: 200,
      endsAt: 300,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](1);
    validatorWeights[0] = 100;
    uint128[] memory validatorCollateralRewardShare = new uint128[](1);
    validatorCollateralRewardShare[0] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](1);
    validatorDelegationRewardShare[0] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](1);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;
    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    epochParams[1].validatorParams = validatorParams;
    epochParams[1].validatorWeights = validatorWeights;
    epochParams[1].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[1].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // epoch1: 100, epoch1: 100
    // epoch1) val1) operator: 50, delegators: 50, comission: 10%
    // epoch2) val1) operator: 50, delegators: 50, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 110 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 90 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);
  }

  function test_claim_multiple_epoch_multiple_validator() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](2);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });
    epochParams[1] = EpochParam({
      epoch: 2,
      startsAt: 200,
      endsAt: 300,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](2);
    validatorWeights[0] = 50;
    validatorWeights[1] = 50;
    uint128[] memory epoch1_validatorCollateralRewardShare = new uint128[](2);
    epoch1_validatorCollateralRewardShare[0] = 80;
    epoch1_validatorCollateralRewardShare[1] = 50;
    uint128[] memory epoch1_validatorDelegationRewardShare = new uint128[](2);
    epoch1_validatorDelegationRewardShare[0] = 20;
    epoch1_validatorDelegationRewardShare[1] = 50;

    uint128[] memory epoch2_validatorCollateralRewardShare = new uint128[](2);
    epoch2_validatorCollateralRewardShare[0] = 50;
    epoch2_validatorCollateralRewardShare[1] = 50;
    uint128[] memory epoch2_validatorDelegationRewardShare = new uint128[](2);
    epoch2_validatorDelegationRewardShare[0] = 50;
    epoch2_validatorDelegationRewardShare[1] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](2);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    validatorParams[1] = ValidatorParam({
      valAddr: makeAddr('val-2'),
      operatorAddr: makeAddr('operator-2'),
      rewardRecipient: makeAddr('rewardRecipient-2'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](1);
    uint256[] memory twabs = new uint256[](1);
    stakers[0] = makeAddr('staker-1');
    twabs[0] = 100;

    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    validatorParams[1].stakers = stakers;
    validatorParams[1].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = epoch1_validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = epoch1_validatorDelegationRewardShare;

    epochParams[1].validatorParams = validatorParams;
    epochParams[1].validatorWeights = validatorWeights;
    epochParams[1].validatorCollateralRewardShare = epoch2_validatorCollateralRewardShare;
    epochParams[1].validatorDelegationRewardShare = epoch2_validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    // epoch1: 100, epoch2: 100
    // epoch1) val1) operator: 80%, delegators: 20%, comission: 10%
    // epoch1) val2) operator: 50%, delegators: 50%, comission: 10%
    // epoch2) val1) operator: 50%, delegators: 50%, comission: 10%
    // epoch2) val2) operator: 50%, delegators: 50%, comission: 10%
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 68.5 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 31.5 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-1')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-1')), 0);

    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 55 ether);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 45 ether);
    assertEq(_distributor.claimOperatorRewards(makeAddr('val-2')), 0);
    assertEq(_distributor.claimStakerRewards(makeAddr('staker-1'), makeAddr('val-2')), 0);
  }

  function test_batch_claim_rewards_by_multiple_stakers() public {
    vm.revertTo(snapshotId);

    EpochParam[] memory epochParams = new EpochParam[](1);
    epochParams[0] = EpochParam({
      epoch: 1,
      startsAt: 100,
      endsAt: 200,
      available: true,
      totalReward: 100 ether,
      validatorParams: new ValidatorParam[](0), // init
      validatorWeights: new uint96[](0), // init
      validatorCollateralRewardShare: new uint128[](0),
      validatorDelegationRewardShare: new uint128[](0)
    });

    uint96[] memory validatorWeights = new uint96[](2);
    validatorWeights[0] = 50;
    validatorWeights[1] = 50;
    uint128[] memory validatorCollateralRewardShare = new uint128[](2);
    validatorCollateralRewardShare[0] = 80;
    validatorCollateralRewardShare[1] = 50;
    uint128[] memory validatorDelegationRewardShare = new uint128[](2);
    validatorDelegationRewardShare[0] = 20;
    validatorDelegationRewardShare[1] = 50;

    ValidatorParam[] memory validatorParams = new ValidatorParam[](2);

    validatorParams[0] = ValidatorParam({
      valAddr: makeAddr('val-1'),
      operatorAddr: makeAddr('operator-1'),
      rewardRecipient: makeAddr('rewardRecipient-1'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    validatorParams[1] = ValidatorParam({
      valAddr: makeAddr('val-2'),
      operatorAddr: makeAddr('operator-2'),
      rewardRecipient: makeAddr('rewardRecipient-2'),
      comissionRate: 1000,
      stakers: new address[](0), // init
      twabs: new uint256[](0) // init
     });
    address[] memory stakers = new address[](3);
    uint256[] memory twabs = new uint256[](3);
    stakers[0] = makeAddr('staker-1');
    stakers[1] = makeAddr('staker-2');
    stakers[2] = makeAddr('staker-3');
    twabs[0] = 50;
    twabs[1] = 25;
    twabs[2] = 25;

    validatorParams[0].stakers = stakers;
    validatorParams[0].twabs = twabs;

    validatorParams[1].stakers = stakers;
    validatorParams[1].twabs = twabs;

    epochParams[0].validatorParams = validatorParams;
    epochParams[0].validatorWeights = validatorWeights;
    epochParams[0].validatorCollateralRewardShare = validatorCollateralRewardShare;
    epochParams[0].validatorDelegationRewardShare = validatorDelegationRewardShare;

    _setUpEpochs(epochParams);

    address[] memory valAddrs = new address[](2);
    valAddrs[0] = makeAddr('val-1');
    valAddrs[1] = makeAddr('val-2');
    assertEq(_distributor.batchClaimOperatorRewards(valAddrs), 41 ether + 27.5 ether);

    address[][] memory valAddrsArr = new address[][](3);
    valAddrsArr[0] = valAddrs;
    valAddrsArr[1] = valAddrs;
    valAddrsArr[2] = valAddrs;
    assertEq(_distributor.batchClaimStakerRewards(stakers, valAddrsArr), 31.5 ether);
  }

  function _setUpEpochs(EpochParam[] memory params) internal {
    for (uint256 i = 0; i < params.length; i++) {
      // ========== epoch setup ==========
      EpochParam memory epochParam = params[i];

      // For TWAB calculating
      vm.warp(epochParam.startsAt);

      _epochFeed.setRet(
        IEpochFeeder.timeAt.selector, abi.encode(epochParam.epoch), false, abi.encode(epochParam.startsAt)
      );
      _epochFeed.setRet(
        IEpochFeeder.timeAt.selector, abi.encode(epochParam.epoch + 1), false, abi.encode(epochParam.endsAt - 1)
      );

      if (epochParam.available) {
        _contributionFeed.setRet(
          IValidatorContributionFeed.available.selector, abi.encode(epochParam.epoch), false, abi.encode(true)
        );
      }

      _govMITOEmission.setRet(
        IGovMITOEmission.validatorReward.selector,
        abi.encode(epochParam.epoch),
        false,
        abi.encode(epochParam.totalReward)
      );

      _validatorManager.setRet(IValidatorManager.MAX_COMMISSION_RATE.selector, '', false, abi.encode(10000));

      // ========== validator setup ==========
      uint128 totalWeight = 0;
      for (uint256 j = 0; j < epochParam.validatorParams.length; j++) {
        ValidatorParam memory validatorParam = epochParam.validatorParams[j];

        _validatorManager.setRet(
          IValidatorManager.validatorInfo.selector,
          abi.encode(validatorParam.valAddr),
          false,
          abi.encode(
            IValidatorManager.ValidatorInfoResponse(
              '', // bytes valKey;
              validatorParam.valAddr, // address valAddr;
              validatorParam.operatorAddr, // address operator;
              validatorParam.rewardRecipient, // address rewardRecipient;
              validatorParam.comissionRate, // uint256 commissionRate;
              '' // bytes metadata;
            )
          )
        );
        _validatorManager.setRet(
          IValidatorManager.validatorInfoAt.selector,
          abi.encode(epochParam.epoch, validatorParam.valAddr),
          false,
          abi.encode(
            IValidatorManager.ValidatorInfoResponse(
              '', // bytes valKey;
              validatorParam.valAddr, // address valAddr;
              validatorParam.operatorAddr, // address operator;
              validatorParam.rewardRecipient, // address rewardRecipient;
              validatorParam.comissionRate, // uint256 commissionRate;
              '' // bytes metadata;
            )
          )
        );
        _contributionFeed.setRet(
          IValidatorContributionFeed.weightOf.selector,
          abi.encode(epochParam.epoch, validatorParam.valAddr),
          false,
          abi.encode(
            ValidatorWeight(
              validatorParam.valAddr, // address addr;
              epochParam.validatorWeights[j], // uint96 weight; // max 79 billion * 1e18
              epochParam.validatorCollateralRewardShare[j], // uint128 collateralRewardShare;
              epochParam.validatorDelegationRewardShare[j] // uint128 delegationRewardShare;
            ),
            true
          )
        );
        totalWeight += epochParam.validatorWeights[j];

        for (uint256 k = 0; k < validatorParam.stakers.length; k++) {
          address staker = validatorParam.stakers[k];
          uint256 amount = validatorParam.twabs[k];
          _stakingHub.notifyStake(validatorParam.valAddr, staker, amount);
        }
      }

      _contributionFeed.setRet(
        IValidatorContributionFeed.summary.selector,
        abi.encode(epochParam.epoch),
        false,
        abi.encode(
          totalWeight, // uint128 totalWeight;
          uint128(epochParam.validatorParams.length) // uint128 numOfValidators;
        )
      );
    }

    uint256 lastEpoch = params[params.length - 1].epoch + 1;
    uint256 lastEpochTime = params[params.length - 1].endsAt;
    _epochFeed.setRet(IEpochFeeder.epoch.selector, '', false, abi.encode(lastEpoch));
    _epochFeed.setRet(IEpochFeeder.timeAt.selector, abi.encode(lastEpoch), false, abi.encode(lastEpochTime));

    vm.warp(lastEpochTime);
  }
}
