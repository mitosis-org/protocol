// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import { WETH } from '@solady/tokens/WETH.sol';

import { GovernanceEntrypoint } from '../../../src/branch/governance/GovernanceEntrypoint.sol';
import { MitosisVault } from '../../../src/branch/MitosisVault.sol';
import { MitosisVaultEntrypoint } from '../../../src/branch/MitosisVaultEntrypoint.sol';
import { BaseDecoderAndSanitizer } from
  '../../../src/branch/strategy/manager/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol';
import { TheoDepositVaultDecoderAndSanitizer } from
  '../../../src/branch/strategy/manager/DecodersAndSanitizers/TheoDepositVaultDecoderAndSanitizer.sol';
import { ManagerWithMerkleVerification } from '../../../src/branch/strategy/manager/ManagerWithMerkleVerification.sol';
import { MatrixStrategyExecutor } from '../../../src/branch/strategy/MatrixStrategyExecutor.sol';
import { MatrixStrategyExecutorFactory } from '../../../src/branch/strategy/MatrixStrategyExecutorFactory.sol';
import { TheoTally } from '../../../src/branch/strategy/tally/TheoTally.sol';
import { IMitosisVault } from '../../../src/interfaces/branch/IMitosisVault.sol';
import { IMatrixStrategyExecutor } from '../../../src/interfaces/branch/strategy/IMatrixStrategyExecutor.sol';
import { IWrappedNativeToken } from '../../../src/interfaces/IWrappedNativeToken.sol';
import { Timelock } from '../../../src/lib/Timelock.sol';
import '../Functions.sol';
import { BranchConfigs } from '../types/BranchConfigs.sol';
import { BranchImplT } from '../types/BranchImplT.sol';
import { BranchProxyT } from '../types/BranchProxyT.sol';
import { AbstractDeployer } from './AbstractDeployer.sol';

abstract contract BranchDeployer is AbstractDeployer {
  string private constant _URL_BASE = 'mitosis.test.branch';

  string private branchChainName;

  modifier withBranchChainName(string memory chain) {
    branchChainName = cat('branch[', chain, ']');

    _;

    branchChainName = '';
  }

  function deployBranch(
    string memory chain,
    address mailbox,
    address owner,
    uint32 hubDomain,
    bytes32 hubMitosisVaultEntrypointAddress,
    bytes32 hubGovernanceEntrypointAddress,
    BranchConfigs.DeployConfig memory config
  ) internal withBranchChainName(chain) returns (BranchImplT.Chain memory impl, BranchProxyT.Chain memory proxy) {
    (impl.mitosisVault, proxy.mitosisVault) = _dpbMitosisVault(IWrappedNativeToken(payable(address(new WETH()))), owner);

    (
      impl.mitosisVaultEntrypoint, //
      proxy.mitosisVaultEntrypoint
    ) = _dpbMitosisVaultEntrypoint(owner, mailbox, proxy.mitosisVault, hubDomain, hubMitosisVaultEntrypointAddress);

    (
      impl.governance.timelock, //
      proxy.governance.timelock
    ) = _dphTimelock(owner, config.timelock);

    (
      impl.governance.entrypoint, //
      proxy.governance.entrypoint
    ) = _dpbGovernanceEntrypoint(owner, mailbox, proxy.governance.timelock, hubDomain, hubGovernanceEntrypointAddress);

    impl.strategy.executor = deploy(
      _urlBI('.matrix.strategy-executor'), //
      type(MatrixStrategyExecutor).creationCode
    );
    (
      impl.strategy.executorFactory, //
      proxy.strategy.executorFactory
    ) = _dpbMatrixStrategyExecutorFactory(owner, impl.strategy.executor);

    (
      impl.strategy.manager.withMerkleVerification, //
      proxy.strategy.manager.withMerkleVerification
    ) = _dpbMatrixStrategyManager(owner);

    proxy.strategy.manager.das.base = BaseDecoderAndSanitizer(
      deploy(
        _urlBP('.matrix.strategy.manager.das.base'), //
        type(BaseDecoderAndSanitizer).creationCode
      )
    );
    proxy.strategy.manager.das.theoDepositVault = TheoDepositVaultDecoderAndSanitizer(
      deploy(
        _urlBP('.matrix.strategy.manager.das.theoDepositVault'), //
        type(TheoDepositVaultDecoderAndSanitizer).creationCode
      )
    );
  }

  // =================================================================================== //
  // ----- Deployment Helpers ----- (dpb = deployBranch to avoid function conflicts)
  // =================================================================================== //

  function _dphTimelock(address owner, BranchConfigs.TimelockConfig memory config) private returns (address, Timelock) {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.governance.timelock', //
      type(Timelock).creationCode,
      abi.encodeCall(Timelock.initialize, (config.minDelay, config.proposers, config.executors, owner))
    );
    return (impl, Timelock(proxy));
  }

  function _dpbGovernanceEntrypoint(
    address owner_,
    address mailbox,
    Timelock timelock,
    uint32 mitosisDomain,
    bytes32 mitosisAddr
  ) private returns (address, GovernanceEntrypoint) {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.governance.entrypoint',
      abi.encodePacked(
        type(GovernanceEntrypoint).creationCode, //
        abi.encode(mailbox, timelock, mitosisDomain, mitosisAddr)
      ),
      abi.encodeCall(GovernanceEntrypoint.initialize, (owner_, address(0), address(0)))
    );
    return (impl, GovernanceEntrypoint(proxy));
  }

  function _dpbMitosisVault(IWrappedNativeToken wrappedNative_, address owner_)
    internal
    returns (address, MitosisVault)
  {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.mitosis-vault',
      abi.encodePacked(type(MitosisVault).creationCode, abi.encode(wrappedNative_)),
      abi.encodeCall(MitosisVault.initialize, (owner_))
    );
    return (impl, MitosisVault(proxy));
  }

  function _dpbMitosisVaultEntrypoint(
    address owner_,
    address mailbox,
    IMitosisVault mitosisVault,
    uint32 mitosisDomain,
    bytes32 mitosisAddr
  ) private returns (address, MitosisVaultEntrypoint) {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.mitosis-vault-entrypoint',
      abi.encodePacked(
        type(MitosisVaultEntrypoint).creationCode, //
        abi.encode(mailbox, mitosisVault, mitosisDomain, mitosisAddr)
      ),
      abi.encodeCall(MitosisVaultEntrypoint.initialize, (owner_, address(0), address(0)))
    );
    return (impl, MitosisVaultEntrypoint(proxy));
  }

  function _dpbMatrixStrategyExecutorFactory(address owner_, address matrixStrategyExecutor)
    private
    returns (address, MatrixStrategyExecutorFactory)
  {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.matrix-strategy-executor-factory',
      type(MatrixStrategyExecutorFactory).creationCode,
      abi.encodeCall(MatrixStrategyExecutorFactory.initialize, (owner_, matrixStrategyExecutor))
    );
    return (impl, MatrixStrategyExecutorFactory(proxy));
  }

  function _dpbMatrixStrategyManager(address owner_) private returns (address, ManagerWithMerkleVerification) {
    (address impl, address payable proxy) = deployImplAndProxy(
      branchChainName,
      '.matrix-strategy-manager',
      type(ManagerWithMerkleVerification).creationCode,
      abi.encodeCall(ManagerWithMerkleVerification.initialize, (owner_))
    );
    return (impl, ManagerWithMerkleVerification(proxy));
  }

  // =================================================================================== //
  // ----- Utility Helpers -----
  // =================================================================================== //

  function _urlBI(string memory name) private view returns (string memory) {
    return _urlI(branchChainName, name);
  }

  function _urlBP(string memory name) private view returns (string memory) {
    return _urlP(branchChainName, name);
  }
}
