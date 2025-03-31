// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;
import { IPostDispatchHook } from '@hpl/interfaces/hooks/IPostDispatchHook.sol';
import { IInterchainSecurityModule } from '@hpl/interfaces/IInterchainSecurityModule.sol';
import { IMailbox } from '@hpl/interfaces/IMailbox.sol';
import { Message } from '@hpl/libs/Message.sol';
import { PackageVersioned } from '@hpl/PackageVersioned.sol';

import { Address } from '@oz/utils/Address.sol';
import { OwnableUpgradeable } from '@ozu/access/OwnableUpgradeable.sol';








/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

abstract contract MailboxClient is OwnableUpgradeable, PackageVersioned {
  using Message for bytes;

  event HookSet(address _hook);
  event IsmSet(address _ism);

  IMailbox public immutable mailbox;

  uint32 public immutable localDomain;

  IPostDispatchHook public hook;

  IInterchainSecurityModule public interchainSecurityModule;

  uint256[48] private __GAP; // gap for upgrade safety

  // ============ Modifiers ============
  modifier onlyContract(address _contract) {
    require(_contract.code.length > 0, 'MailboxClient: invalid mailbox');
    _;
  }

  modifier onlyContractOrNull(address _contract) {
    require(_contract.code.length > 0 || _contract == address(0), 'MailboxClient: invalid contract setting');
    _;
  }

  /**
   * @notice Only accept messages from a Hyperlane Mailbox contract
   */
  modifier onlyMailbox() {
    require(msg.sender == address(mailbox), 'MailboxClient: sender not mailbox');
    _;
  }

  constructor(address _mailbox) onlyContract(_mailbox) {
    mailbox = IMailbox(_mailbox);
    localDomain = mailbox.localDomain();
    _transferOwnership(msg.sender);
  }

  /**
   * @notice Sets the address of the application's custom hook.
   * @param _hook The address of the hook contract.
   */
  function setHook(address _hook) public virtual onlyContractOrNull(_hook) onlyOwner {
    hook = IPostDispatchHook(_hook);
    emit HookSet(_hook);
  }

  /**
   * @notice Sets the address of the application's custom interchain security module.
   * @param _module The address of the interchain security module contract.
   */
  function setInterchainSecurityModule(address _module) public onlyContractOrNull(_module) onlyOwner {
    interchainSecurityModule = IInterchainSecurityModule(_module);
    emit IsmSet(_module);
  }

  // ======== Initializer =========
  function _MailboxClient_initialize(address _hook, address _interchainSecurityModule, address _owner)
    internal
    onlyInitializing
  {
    __Ownable_init(_owner);

    setHook(_hook);
    setInterchainSecurityModule(_interchainSecurityModule);
  }

  function _isLatestDispatched(bytes32 id) internal view returns (bool) {
    return mailbox.latestDispatchedId() == id;
  }

  function _isDelivered(bytes32 id) internal view returns (bool) {
    return mailbox.delivered(id);
  }
}
