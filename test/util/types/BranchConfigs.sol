// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { stdJson } from '@std/StdJson.sol';
import { Vm, VmSafe } from '@std/Vm.sol';

import { SafeCast } from '@oz/utils/math/SafeCast.sol';

import { LibString } from '@solady/utils/LibString.sol';

import '../Functions.sol';

library BranchConfigs {
  using LibString for *;
  using stdJson for string;
  using SafeCast for uint256;

  address private constant VM_ADDRESS = address(uint160(uint256(keccak256('hevm cheat code'))));
  Vm private constant vm = Vm(VM_ADDRESS);

  struct DeployConfig {
    bytes placeholder;
  }

  // =================================================================================== //
  // ----- FS Helpers -----
  // =================================================================================== //

  function read(string memory path) internal view returns (DeployConfig memory) {
    string memory json = vm.readFile(path);
    return decodeDeployConfig(json);
  }

  function write(DeployConfig memory v, string memory path) internal {
    if (vm.exists(path)) vm.removeFile(path); // replace
    string memory json = encode(v);
    vm.writeJson(json, path);
    vm.writeFile(path, cat(vm.readFile(path), '\n'));
  }

  // =================================================================================== //
  // ----- Codec Helpers -----
  // =================================================================================== //

  function encode(DeployConfig memory) internal pure returns (string memory o) {
    o = '{}';
  }

  function decodeDeployConfig(string memory) internal pure returns (DeployConfig memory) { }
}
