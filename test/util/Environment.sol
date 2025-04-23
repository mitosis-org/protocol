// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MockMailbox } from '@hpl/mock/MockMailbox.sol';
import { TestInterchainGasPaymaster } from '@hpl/test/TestInterchainGasPaymaster.sol';
import { TestIsm } from '@hpl/test/TestIsm.sol';

import { BranchDeployer } from './deployers/BranchDeployer.sol';
import { HubDeployer } from './deployers/HubDeployer.sol';

abstract contract Environment is HubDeployer, BranchDeployer {
  error MailboxNotFound(uint32 domain);

  uint32 private nextDomain = 12345;

  MockMailbox[] private _mailboxes;
  mapping(uint32 => uint256) private _mailboxByDomain;

  function setUp() public virtual override {
    super.setUp();
  }

  function mailbox(uint32 domain) internal view returns (MockMailbox) {
    MockMailbox mailbox_ = _mailboxes[_mailboxByDomain[domain]];
    require(mailbox_.localDomain() == domain, MailboxNotFound(domain));
    return mailbox_;
  }

  function addDomain() internal returns (uint32) {
    uint32 domain = nextDomain++;

    MockMailbox mailbox_ = new MockMailbox(domain);
    _mailboxes.push(mailbox_);
    _mailboxByDomain[domain] = _mailboxes.length - 1;

    mailbox_.setDefaultIsm(address(new TestIsm()));
    mailbox_.setDefaultHook(address(new TestInterchainGasPaymaster()));

    for (uint256 i = 0; i < _mailboxes.length - 1; i++) {
      MockMailbox src = _mailboxes[i];
      src.addRemoteMailbox(domain, mailbox_);
      mailbox_.addRemoteMailbox(src.localDomain(), src);
    }

    return domain;
  }
}
