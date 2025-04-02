// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DepositContract{
    // Swap structure
    struct Swap {
        bytes32 swapId;
        address initiator; // User's address on Chain1
        address acceptor; // User on Chain2 who accepts the swap
        address sourceTokenAddress; // Token address on Chain1
        uint256 sourceAmount;
        address destinationTokenAddress; // Token address on Chain2
        uint256 destinationAmount;
        address receivingAddress; // Address that will receive tokens on Chain2
        uint256 timelock;
        bool isAcknowledged;
        bool isDeposited;
        bool isCompleted;
    }
    // Mapping of swapId to Swap
    mapping(bytes32 => Swap) public swaps;
    // Events
    event SwapAcknowledged(bytes32 indexed swapId, address indexed acceptor);
    event TokensDeposited(bytes32 indexed swapId, address indexed acceptor, uint256 amount);
    event SwapCompleted(bytes32 indexed swapId, address indexed initiator, address indexed acceptor, address recipient, uint256 amount);
    event SwapCancelled(bytes32 indexed swapId, address indexed acceptor);
    // user acknowledges the swap request
    function acknowledgeSwap(
        bytes32 _swapId,
        address _initiator,
        address _sourceTokenAddress,
        uint256 _sourceAmount,
        address _destinationTokenAddress,
        uint256 _destinationAmount,
        address _receivingAddress,
        uint256 _timelock
    ) external {
        require(swaps[_swapId].swapId == bytes32(0), "Swap already acknowledged");
        require(block.timestamp < _timelock, "Swap has expired");
        require(_destinationAmount > 0, "Amount must be greater than 0");
        // Register the swap
        swaps[_swapId] = Swap({
            swapId: _swapId,
            initiator: _initiator,
            acceptor: msg.sender,
            sourceTokenAddress: _sourceTokenAddress,
            sourceAmount: _sourceAmount,
            destinationTokenAddress: _destinationTokenAddress,
            destinationAmount: _destinationAmount,
            receivingAddress: _receivingAddress,
            timelock: _timelock,
            isAcknowledged: true,
            isDeposited: false,
            isCompleted: false
        });
        emit SwapAcknowledged(_swapId, msg.sender);
    }
    // Deposit tokens for a swap after seeing TokensDeposited event on Chain1
    function depositTokens(bytes32 _swapId) external {
        Swap storage swap = swaps[_swapId];
        require(swap.acceptor == msg.sender, "Not the swap acceptor");
        require(swap.isAcknowledged, "Swap not acknowledged");
        require(!swap.isDeposited, "Tokens already deposited");
        require(block.timestamp < swap.timelock, "Swap has expired");
        // Transfer tokens from user to this contract
        IERC20 token = IERC20(swap.destinationTokenAddress);
        require(token.transferFrom(msg.sender, address(this), swap.destinationAmount), "Token transfer failed");
        swap.isDeposited = true;
        emit TokensDeposited(_swapId, msg.sender, swap.destinationAmount);
    }
    //callback function for rsc to call in order to transfer funds to user's receiving address
    function completeSwap(bytes32 _swapId) external {
        Swap storage swap = swaps[_swapId];
        require(swap.isAcknowledged, "Swap not acknowledged");
        require(swap.isDeposited, "Tokens not deposited");
        require(!swap.isCompleted, "Swap already completed");
        require(block.timestamp < swap.timelock, "Swap has expired");
        swap.isCompleted = true;
        IERC20 token = IERC20(swap.destinationTokenAddress);
        require(token.transfer(swap.receivingAddress, swap.destinationAmount), "Token transfer failed");
        emit SwapCompleted(
            _swapId, 
            swap.initiator, 
            swap.acceptor, 
            swap.receivingAddress, 
            swap.destinationAmount
        );
    }
}