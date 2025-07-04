// SPDX-License-Identifier: MIT OR Apache-2.0
// Forked from @hyperlane-xyz/core (https://github.com/hyperlane-xyz/hyperlane-monorepo)
// - rev: https://github.com/hyperlane-xyz/hyperlane-monorepo/commit/42ccee13eb99313a4a078f36938aec6dab16990c
// Modified by Mitosis Team
//
// CHANGES:
// - Use ERC7201 Namespaced Storage for storage variables.
pragma solidity >=0.6.11;

import { IPostDispatchHook } from '@hpl/interfaces/hooks/IPostDispatchHook.sol';
import { IInterchainSecurityModule } from '@hpl/interfaces/IInterchainSecurityModule.sol';
import { IMessageRecipient } from '@hpl/interfaces/IMessageRecipient.sol';
import { EnumerableMapExtended } from '@hpl/libs/EnumerableMapExtended.sol';

import { Strings } from '@oz/utils/Strings.sol';

import { ERC7201Utils } from '../../lib/ERC7201Utils.sol';
import { MailboxClient } from './MailboxClient.sol';

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
abstract contract Router is MailboxClient, IMessageRecipient {
  using EnumerableMapExtended for EnumerableMapExtended.UintToBytes32Map;
  using Strings for uint32;
  using ERC7201Utils for string;

  struct RouterStorage {
    EnumerableMapExtended.UintToBytes32Map routers;
  }

  string private constant _ROUTER_STORAGE_NAMESPACE = 'hyperlane.storage.Router';
  bytes32 private immutable _slot = _ROUTER_STORAGE_NAMESPACE.storageSlot();

  function _getHplRouterStorage() private view returns (RouterStorage storage $) {
    bytes32 slot = _slot;
    assembly {
      $.slot := slot
    }
  }

  constructor(address _mailbox) MailboxClient(_mailbox) { }

  modifier onlyRouterManager() {
    _authorizeConfigureRoute(_msgSender());
    _;
  }

  // =========================== NOTE: VIRTUAL FUNCTIONS =========================== //

  function _authorizeConfigureRoute(address) internal virtual;

  // ============ External functions ============
  function domains() external view returns (uint32[] memory) {
    return _getHplRouterStorage().routers.uint32Keys();
  }

  /**
   * @notice Returns the address of the Router contract for the given domain
   * @param _domain The remote domain ID.
   * @dev Returns 0 address if no router is enrolled for the given domain
   * @return router The address of the Router contract for the given domain
   */
  function routers(uint32 _domain) public view virtual returns (bytes32) {
    (, bytes32 _router) = _getHplRouterStorage().routers.tryGet(_domain);
    return _router;
  }

  /**
   * @notice Unregister the domain
   * @param _domain The domain of the remote Application Router
   */
  function unenrollRemoteRouter(uint32 _domain) external virtual onlyRouterManager {
    _unenrollRemoteRouter(_domain);
  }

  /**
   * @notice Register the address of a Router contract for the same Application on a remote chain
   * @param _domain The domain of the remote Application Router
   * @param _router The address of the remote Application Router
   */
  function enrollRemoteRouter(uint32 _domain, bytes32 _router) external virtual onlyRouterManager {
    _enrollRemoteRouter(_domain, _router);
  }

  /**
   * @notice Batch version of `enrollRemoteRouter`
   * @param _domains The domains of the remote Application Routers
   * @param _addresses The addresses of the remote Application Routers
   */
  function enrollRemoteRouters(uint32[] calldata _domains, bytes32[] calldata _addresses)
    external
    virtual
    onlyRouterManager
  {
    require(_domains.length == _addresses.length, '!length');
    uint256 length = _domains.length;
    for (uint256 i = 0; i < length; i += 1) {
      _enrollRemoteRouter(_domains[i], _addresses[i]);
    }
  }

  /**
   * @notice Batch version of `unenrollRemoteRouter`
   * @param _domains The domains of the remote Application Routers
   */
  function unenrollRemoteRouters(uint32[] calldata _domains) external virtual onlyRouterManager {
    uint256 length = _domains.length;
    for (uint256 i = 0; i < length; i += 1) {
      _unenrollRemoteRouter(_domains[i]);
    }
  }

  /**
   * @notice Handles an incoming message
   * @param _origin The origin domain
   * @param _sender The sender address
   * @param _message The message
   */
  function handle(uint32 _origin, bytes32 _sender, bytes calldata _message)
    external
    payable
    virtual
    override
    onlyMailbox
  {
    bytes32 _router = _mustHaveRemoteRouter(_origin);
    require(_router == _sender, 'Enrolled router does not match sender');
    _handle(_origin, _sender, _message);
  }

  // ============ Virtual functions ============
  function _handle(uint32 _origin, bytes32 _sender, bytes calldata _message) internal virtual;

  // ============ Internal functions ============

  /**
   * @notice Set the router for a given domain
   * @param _domain The domain
   * @param _address The new router
   */
  function _enrollRemoteRouter(uint32 _domain, bytes32 _address) internal virtual {
    _getHplRouterStorage().routers.set(_domain, _address);
  }

  /**
   * @notice Remove the router for a given domain
   * @param _domain The domain
   */
  function _unenrollRemoteRouter(uint32 _domain) internal virtual {
    require(_getHplRouterStorage().routers.remove(_domain), _domainNotFoundError(_domain));
  }

  /**
   * @notice Return true if the given domain / router is the address of a remote Application Router
   * @param _domain The domain of the potential remote Application Router
   * @param _address The address of the potential remote Application Router
   */
  function _isRemoteRouter(uint32 _domain, bytes32 _address) internal view returns (bool) {
    return routers(_domain) == _address;
  }

  /**
   * @notice Assert that the given domain has an Application Router registered and return its address
   * @param _domain The domain of the chain for which to get the Application Router
   * @return _router The address of the remote Application Router on _domain
   */
  function _mustHaveRemoteRouter(uint32 _domain) internal view returns (bytes32) {
    (bool contained, bytes32 _router) = _getHplRouterStorage().routers.tryGet(_domain);
    if (contained) {
      return _router;
    }
    revert(_domainNotFoundError(_domain));
  }

  function _domainNotFoundError(uint32 _domain) internal pure returns (string memory) {
    return string.concat('No router enrolled for domain: ', _domain.toString());
  }

  function _Router_dispatch(
    uint32 _destinationDomain,
    uint256 _value,
    bytes memory _messageBody,
    bytes memory _hookMetadata,
    address _hook
  ) internal returns (bytes32) {
    bytes32 _router = _mustHaveRemoteRouter(_destinationDomain);
    return mailbox.dispatch{ value: _value }(
      _destinationDomain, _router, _messageBody, _hookMetadata, IPostDispatchHook(_hook)
    );
  }

  /**
   * DEPRECATED: Use `_Router_dispatch` instead
   * @dev For backward compatibility with v2 client contracts
   */
  function _dispatch(uint32 _destinationDomain, bytes memory _messageBody) internal returns (bytes32) {
    return _Router_dispatch(_destinationDomain, msg.value, _messageBody, '', address(hook()));
  }

  function _Router_quoteDispatch(
    uint32 _destinationDomain,
    bytes memory _messageBody,
    bytes memory _hookMetadata,
    address _hook
  ) internal view returns (uint256) {
    bytes32 _router = _mustHaveRemoteRouter(_destinationDomain);
    return mailbox.quoteDispatch(_destinationDomain, _router, _messageBody, _hookMetadata, IPostDispatchHook(_hook));
  }

  /**
   * DEPRECATED: Use `_Router_quoteDispatch` instead
   * @dev For backward compatibility with v2 client contracts
   */
  function _quoteDispatch(uint32 _destinationDomain, bytes memory _messageBody) internal view returns (uint256) {
    return _Router_quoteDispatch(_destinationDomain, _messageBody, '', address(hook()));
  }
}
