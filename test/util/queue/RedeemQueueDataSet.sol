// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibRedeemQueue } from '../../../src/lib/LibRedeemQueue.sol';
import { RedeemQueueWrapper } from './RedeemQueueWrapper.sol';

struct DataSet {
  address recipient;
  uint256 shares;
  uint256 assets;
}

struct RequestSet {
  uint256 itemIndex;
  LibRedeemQueue.Request request;
}

library LibDataSet {
  using LibRedeemQueue for *;

  function recipients(DataSet[] memory dataset) internal pure returns (address[] memory recipients_) {
    uint256 recipientCount = 0;
    address[] memory recipientsBuffer = new address[](dataset.length);
    for (uint256 i = 0; i < dataset.length; i++) {
      bool found = false;
      for (uint256 j = 0; j < recipientsBuffer.length; j++) {
        if (recipientsBuffer[j] != dataset[i].recipient) continue;
        found = true;
        break;
      }

      if (!found) {
        recipientsBuffer[recipientCount] = dataset[i].recipient;
        recipientCount++;
      }
    }

    recipients_ = new address[](recipientCount);
    for (uint256 i = 0; i < recipientCount; i++) {
      recipients_[i] = recipientsBuffer[i];
    }

    return recipients_;
  }

  function requests(DataSet[] memory dataset, RedeemQueueWrapper queue, address recipient)
    internal
    view
    returns (RequestSet[] memory requests_)
  {
    uint256 itemCount = 0;
    RequestSet[] memory requestsBuffer = new RequestSet[](dataset.length);
    for (uint256 i = 0; i < dataset.length; i++) {
      if (dataset[i].recipient != recipient) continue;

      requestsBuffer[itemCount] = RequestSet({ itemIndex: i, request: queue.get(i) });
      itemCount++;
    }

    requests_ = new RequestSet[](itemCount);
    for (uint256 i = 0; i < itemCount; i++) {
      requests_[i] = requestsBuffer[i];
    }

    return requests_;
  }

  function totalRequestedShares(DataSet[] memory dataset) internal pure returns (uint256 totalRequested) {
    return _accUint256(dataset, _shares);
  }

  function totalRequestedAssets(DataSet[] memory dataset) internal pure returns (uint256 totalRequested) {
    return _accUint256(dataset, _assets);
  }

  function _shares(DataSet memory data) private pure returns (uint256) {
    return data.shares;
  }

  function _assets(DataSet memory data) private pure returns (uint256) {
    return data.assets;
  }

  function _accUint256(DataSet[] memory dataset, function(DataSet memory) pure returns (uint256) f)
    private
    pure
    returns (uint256 acc)
  {
    for (uint256 i = 0; i < dataset.length; i++) {
      acc += f(dataset[i]);
    }
    return acc;
  }
}
