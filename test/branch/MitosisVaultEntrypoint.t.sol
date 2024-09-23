// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from '@std/Test.sol';

import { ERC1967Factory } from '@solady/utils/ERC1967Factory.sol';

import { ProxyAdmin } from '@oz-v5/proxy/transparent/ProxyAdmin.sol';
import { TransparentUpgradeableProxy } from '@oz-v5/proxy/transparent/TransparentUpgradeableProxy.sol';

import { MitosisVault } from '../../src/branch/MitosisVault.sol';
import { MitosisVaultEntrypoint } from '../../src/branch/MitosisVaultEntrypoint.sol';

contract MitosisVaultEntrypointTest is Test {
  MitosisVault internal _mitosisVault;
  ProxyAdmin internal _proxyAdmin;

  address immutable owner = makeAddr('owner');

  function setUp() public {
    _proxyAdmin = new ProxyAdmin(owner);
    MitosisVault mitosisVaultImpl = new MitosisVault();

    _mitosisVault = MitosisVault(
      payable(
        address(
          new TransparentUpgradeableProxy(
            address(_proxyAdmin), address(_proxyAdmin), abi.encodeCall(mitosisVaultImpl.initialize, (owner))
          )
        )
      )
    );
  }
}
