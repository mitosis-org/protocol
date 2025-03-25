// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IVotes } from '@oz-v5/governance/utils/IVotes.sol';
import { ECDSA } from '@oz-v5/utils/cryptography/ECDSA.sol';

import { OwnableUpgradeable } from '@ozu-v5/access/OwnableUpgradeable.sol';
import { UUPSUpgradeable } from '@ozu-v5/proxy/utils/UUPSUpgradeable.sol';
import { EIP712Upgradeable } from '@ozu-v5/utils/cryptography/EIP712Upgradeable.sol';
import { NoncesUpgradeable } from '@ozu-v5/utils/NoncesUpgradeable.sol';

import { ISudoVotes } from '../../interfaces/lib/ISudoVotes.sol';
import { StdError } from '../../lib/StdError.sol';

contract MITOGovernanceVP is IVotes, OwnableUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable {
  event TokensUpdated(ISudoVotes[] oldTokens, ISudoVotes[] newTokens);

  error MITOGovernanceVP__ZeroLengthTokens();
  error MITOGovernanceVP__InvalidToken(address token);
  error MITOGoverannceVP__MaxTokensLengthExceeded(uint256 max, uint256 actual);

  uint256 public constant MAX_TOKENS = 25;

  bytes32 private constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  ISudoVotes[] private _tokens;

  constructor() {
    _disableInitializers();
  }

  function initialize(address owner_, ISudoVotes[] calldata tokens_) external initializer {
    __Ownable_init(owner_);
    __UUPSUpgradeable_init();
    __EIP712_init('Mitosis Governance VP', '1');
    __Nonces_init();

    _tokens = tokens_;
  }

  function tokens() external view returns (ISudoVotes[] memory) {
    return _tokens;
  }

  function updateTokens(ISudoVotes[] calldata newTokens_) external onlyOwner {
    require(newTokens_.length > 0, MITOGovernanceVP__ZeroLengthTokens());
    require(newTokens_.length <= MAX_TOKENS, MITOGoverannceVP__MaxTokensLengthExceeded(MAX_TOKENS, newTokens_.length));

    uint256 newTokensLen = newTokens_.length;
    for (uint256 i = 0; i < newTokensLen;) {
      require(
        address(newTokens_[i]).code.length > 0, //
        MITOGovernanceVP__InvalidToken(address(newTokens_[i]))
      );

      unchecked {
        i++;
      }
    }

    ISudoVotes[] memory oldTokens = _tokens;
    _tokens = newTokens_;

    emit TokensUpdated(oldTokens, newTokens_);
  }

  function getVotes(address account) external view returns (uint256) {
    uint256 votes = 0;
    uint256 tokensLen = _tokens.length;
    for (uint256 i = 0; i < tokensLen; i++) {
      votes += _tokens[i].getVotes(account);
    }
    return votes;
  }

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    uint256 votes = 0;
    uint256 tokensLen = _tokens.length;
    for (uint256 i = 0; i < tokensLen; i++) {
      votes += _tokens[i].getPastVotes(account, timepoint);
    }
    return votes;
  }

  function getPastTotalSupply(uint256 timepoint) external view returns (uint256) {
    uint256 totalSupply = 0;
    uint256 tokensLen = _tokens.length;
    for (uint256 i = 0; i < tokensLen; i++) {
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
    uint256 tokensLen = _tokens.length;
    for (uint256 i = 0; i < tokensLen; i++) {
      _tokens[i].sudoDelegate(account, delegatee);
    }
  }

  function _authorizeUpgrade(address) internal override onlyOwner { }
}
