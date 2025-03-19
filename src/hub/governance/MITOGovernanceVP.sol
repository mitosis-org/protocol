// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';
import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { IGovMITO } from '../../interfaces/hub/IGovMITO.sol';
import { IValidatorStaking } from '../../interfaces/hub/validator/IValidatorStaking.sol';
import { StdError } from '../../lib/StdError.sol';

interface ISudoDelegate {
  function sudoDelegate(address account, address delegatee) external;
}

contract MITOGovernanceVP is IVotes, OwnableUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
  event TokensUpdated(IVotes[] oldTokens, IVotes[] newTokens);

  bytes32 private constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  IVotes[] private _tokens;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, IVotes[] calldata tokens_) external initializer {
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
    __EIP712_init('Mitosis Governance VP', '1');
    __Nonces_init();

    _tokens = tokens_;
  }

  function tokens() external view returns (IVotes[] memory) {
    return _tokens;
  }

  function updateTokens(IVotes[] calldata newTokens_) external onlyOwner {
    IVotes[] memory oldTokens = _tokens;
    _tokens = newTokens_;

    emit TokensUpdated(oldTokens, newTokens_);
  }

  function getVotes(address account) external view returns (uint256) {
    uint256 votes = 0;
    for (uint256 i = 0; i < _tokens.length; i++) {
      votes += _tokens[i].getVotes(account);
    }
    return votes;
  }

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    uint256 votes = 0;
    for (uint256 i = 0; i < _tokens.length; i++) {
      votes += _tokens[i].getPastVotes(account, timepoint);
    }
    return votes;
  }

  function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
    uint256 totalSupply = 0;
    for (uint256 i = 0; i < _tokens.length; i++) {
      totalSupply += _tokens[i].getPastTotalSupply(timepoint);
    }
    return totalSupply;
  }

  function delegates(address account) external view returns (address) {
    return _tokens[0].delegates(account);
  }

  function delegate(address delegatee) external {
    address account = _msgSender();
    _delegate(account, delegatee);
  }

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
    require(block.timestamp <= expiry, VotesExpiredSignature(expiry));

    bytes32 hash_ = _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)));
    address signer = ECDSA.recover(hash_, v, r, s);

    _useCheckedNonce(signer, nonce);
    _delegate(signer, delegatee);
  }

  function _delegate(address account, address delegatee) internal virtual {
    for (uint256 i = 0; i < _tokens.length; i++) {
      ISudoDelegate(address(_tokens[i])).sudoDelegate(account, delegatee);
    }
  }

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
