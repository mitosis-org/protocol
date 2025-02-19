// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockContract {
  struct Log {
    bytes4 sig;
    bytes args;
    uint256 value;
  }

  struct Ret {
    bool revert_;
    bytes data;
  }

  mapping(bytes4 => bool) public isStaticCall;
  mapping(bytes4 => Ret) public rets;
  mapping(bytes4 => uint256) public calls;
  mapping(bytes4 => Log[]) public callLogs;

  receive() external payable { }

  fallback() external payable {
    if (!isStaticCall[msg.sig]) {
      calls[msg.sig]++;
      callLogs[msg.sig].push(Log({ sig: msg.sig, args: msg.data[4:], value: msg.value }));
    }

    Ret memory ret = rets[msg.sig];
    bytes memory data = ret.data;
    if (ret.revert_) {
      assembly {
        revert(add(data, 32), mload(data))
      }
    } else {
      assembly {
        return(add(data, 32), mload(data))
      }
    }
  }

  /// @notice Sets a return value for a function call
  /// @param sig The function selector
  /// @param revert_ Whether the function should revert
  /// @param data The return data - this will be revertdata if revert_ is true
  function setRet(bytes4 sig, bool revert_, bytes memory data) external {
    rets[sig] = Ret({ revert_: revert_, data: data });
  }

  /// @notice Sets whether a function call is static
  /// @param sig The function selector
  /// @param isStatic Whether the function call is static
  function setStatic(bytes4 sig, bool isStatic) external {
    isStaticCall[sig] = isStatic;
  }

  function lastCallLog(bytes4 sig) external view returns (Log memory) {
    return _lastCallLog(sig);
  }

  function assertLastCall(bytes4 sig, bytes memory args) external view {
    _assertLastCall(sig, args, 0);
  }

  function assertLastCall(bytes4 sig, bytes memory args, uint256 value) external view {
    _assertLastCall(sig, args, value);
  }

  function _lastCallLog(bytes4 sig) internal view returns (Log memory) {
    return callLogs[sig][callLogs[sig].length - 1];
  }

  function _assertLastCall(bytes4 sig, bytes memory args, uint256 value) internal view {
    Log memory log = _lastCallLog(sig);
    require(log.sig == sig, 'sig mismatch');
    require(keccak256(log.args) == keccak256(args), 'args mismatch');
    require(log.value == value, 'value mismatch');
  }
}
