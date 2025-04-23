// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from '@std/console.sol';

import '../Functions.sol';
import { BranchConfigs } from '../types/BranchConfigs.sol';
import { BranchImplT } from '../types/BranchImplT.sol';
import { BranchProxyT } from '../types/BranchProxyT.sol';
import { AbstractDeployer } from './AbstractDeployer.sol';

abstract contract BranchDeployer is AbstractDeployer {
  string private constant _URL_BASE = 'mitosis.test.branch';

  string private _IMPL_URL;
  string private _PROXY_URL;

  modifier withUrls(string memory chain) {
    _IMPL_URL = cat(_URL_BASE, '[', chain, '].impl.');
    _PROXY_URL = cat(_URL_BASE, '[', chain, '].proxy.');

    _;

    _IMPL_URL = '';
    _PROXY_URL = '';
  }

  function deployBranch(string memory chain, address mailbox, address owner, BranchConfigs.DeployConfig memory config)
    internal
    withUrls(chain)
    returns (BranchImplT.Chain memory impl, BranchProxyT.Chain memory proxy)
  { }

  // =================================================================================== //
  // ----- Utility Helpers -----
  // =================================================================================== //

  function _urlBI(string memory name) private view returns (string memory) {
    return cat(_IMPL_URL, name, '.v1');
  }

  function _urlBP(string memory name) private view returns (string memory) {
    return cat(_PROXY_URL, name);
  }
}
