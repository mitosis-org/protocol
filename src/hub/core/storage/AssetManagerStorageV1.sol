// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AssetManagerEntrypoint } from '../AssetManagerEntrypoint.sol';
import { IMitosisLedger } from '../../../interfaces/hub/core/IMitosisLedger.sol';
import { IEOLVault } from '../../../interfaces/hub/core/IEOLVault.sol';
import { ERC7201Utils } from '../../../lib/ERC7201Utils.sol';

contract AssetManagerStorageV1 {
  using ERC7201Utils for string;

  struct StorageV1 {
    AssetManagerEntrypoint entrypoint;
    IMitosisLedger mitosisLedger;
    // branchAsset 주소가 체인별로 일치할 가능성도 없지느 않기 때문에... 고려를 하는 것이 맞지 않을까? 발생하면 참사니까
    mapping(address hubAsset => mapping(uint256 chainId => address branchAsset)) branchAssets;
    mapping(address branchAsset => mapping(uint256 chainID => address hubAsset)) hubAssets;
    // 에셋 종류마다 EOL ID 할당해줘야 할까? 아니면 통합해서 할당해주어ㅕ야 할까? 일단 타이 구현은 통합 할당이긴 함. 이는 곧 EOL ID => hubAsset 매핑이 있어야 함을 의미
    // 다른 곳에 저장되어야 할 수도?
    mapping(uint256 eolId => IEOLVault eolVault) eolVaults;
  }

  string constant _NAMESPACE = 'mitosis.storage.AssetManagerStorage.v1';
  bytes32 public immutable StorageV1Location = _NAMESPACE.storageSlot();

  function _getStorageV1() internal view returns (StorageV1 storage $) {
    bytes32 slot = StorageV1Location;
    // slither-disable-next-line assembly
    assembly {
      $.slot := slot
    }
  }
}
