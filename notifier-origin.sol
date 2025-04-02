// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract Notifier {
    event FundsTransferred(bytes32 indexed swapId, address indexed recipient, uint256 amount);
    function notifyFundsTransferred(bytes32 _swapId, address _recipient, uint256 _amount) external{
        emit FundsTransferred(_swapId, _recipient, _amount);
    }
}