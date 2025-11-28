// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/// @title SystemContractMock
/// @notice This contract simulates SystemContracts defined by EIP-7251 & EIP-7002.
/// @dev This contract is used for testing purposes only.
///      The receive() function omitted intentionally to catch all requests with fallback().
///      Ignore the warning:
///        Warning (3628): This contract has a payable fallback function, but no receive ether function.
///        Consider adding a receive ether function.
contract SystemContractMock {
  uint256 internal immutable requestSize;
  bytes[] internal requests;
  bool internal failNextFeeRequest;
  bool internal failNextAddRequest;

  /// @notice Constructor
  /// @param _requestSize The expected request size: 96 for consolidation, 56 for withdrawal.
  constructor(uint256 _requestSize) {
    requestSize = _requestSize;
  }

  /// @notice Returns the requests made.
  function getRequests() external view returns (bytes[] memory) {
    return requests;
  }

  function setFailNextFeeRequest(bool _failNextFeeRequest) external {
    failNextFeeRequest = _failNextFeeRequest;
  }

  function setFailNextAddRequest(bool _failNextAddRequest) external {
    failNextAddRequest = _failNextAddRequest;
  }

  function fakeExponential(uint256 numerator) public pure returns (uint256) {
    uint256 DENOMINATOR = 17;
    uint256 i = 1;
    uint256 output = 0;
    uint256 numeratorAccum = DENOMINATOR;

    while (numeratorAccum > 0) {
      output += numeratorAccum;
      numeratorAccum = (numeratorAccum * numerator) / (DENOMINATOR * i);
      i += 1;
    }

    return output / DENOMINATOR;
  }

  fallback(bytes calldata) external payable returns (bytes memory) {
    uint256 feeWei = fakeExponential(requests.length);

    // If calldata is empty, return the fee
    if (msg.data.length == 0) {
      if (failNextFeeRequest) {
        failNextFeeRequest = false;
        revert("fee request failed");
      }

      return abi.encodePacked(bytes32(feeWei));
    }

    if (msg.value < feeWei) {
      console.log("insufficient fee, expected: ", feeWei, " received: ", msg.value);
      revert("insufficient fee");
    }

    if (failNextAddRequest) {
      failNextAddRequest = false;
      revert("add request failed");
    }

    // If calldata is not empty, consider it as a valid request
    if (msg.data.length != requestSize) {
      console.log("invalid calldata length, expected: ", requestSize, " received: ", msg.data.length);
      revert("invalid calldata length");
    }

    requests.push(msg.data);

    // For any add request it returns nothing
    return new bytes(0);
  }
}
