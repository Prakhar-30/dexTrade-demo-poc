// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract SwapInitiator{
    // Swap request structure
    struct SwapRequest {
        address initiator;
        address tokenAddress;
        uint256 amount;
        address receivingAddress; // User's address on the second chain
        address destinationTokenAddress; // Token address on the second chain
        uint256 expectedAmount;
        uint256 timelock; // Expiration time for the swap
        bool isActive;
        bool isDeposited;
        bytes32 swapId;
    }
    // Mapping of swapId to SwapRequest
    mapping(bytes32 => SwapRequest) public swapRequests;
    // Events
    event SwapInitiated(bytes32 indexed swapId, address indexed initiator, address tokenAddress, uint256 amount, address receivingAddress, address destinationTokenAddress, uint256 expectedAmount, uint256 timelock);
    event TokensDeposited(bytes32 indexed swapId, address indexed initiator, uint256 amount);
    event SwapCompleted(bytes32 indexed swapId, address indexed initiator);
    event SwapCancelled(bytes32 indexed swapId, address indexed initiator);
    event TokensWithdrawn(bytes32 indexed swapId, address indexed initiator, uint256 amount);
    // initiate the swap request
    function initiateSwap(
        address _tokenAddress,
        uint256 _amount,
        address _receivingAddress,
        address _destinationTokenAddress,
        uint256 _expectedAmount,
        uint256 _timelock
    ) external returns (bytes32) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_receivingAddress != address(0), "Invalid receiving address");
        require(_destinationTokenAddress != address(0), "Invalid destination token address");
        require(_expectedAmount > 0, "Expected amount must be greater than 0");
        require(_timelock > block.timestamp, "Timelock must be in the future");
        bytes32 swapId = keccak256(abi.encodePacked(
            msg.sender,
            _tokenAddress,
            _amount,
            _receivingAddress,
            _destinationTokenAddress,
            _expectedAmount,
            _timelock,
            block.timestamp
        ));
        SwapRequest memory newSwap = SwapRequest({
            initiator: msg.sender,
            tokenAddress: _tokenAddress,
            amount: _amount,
            receivingAddress: _receivingAddress,
            destinationTokenAddress: _destinationTokenAddress,
            expectedAmount: _expectedAmount,
            timelock: _timelock,
            isActive: true,
            isDeposited: false,
            swapId: swapId
        });
        swapRequests[swapId] = newSwap;
        emit SwapInitiated(
            swapId,
            msg.sender,
            _tokenAddress,
            _amount,
            _receivingAddress,
            _destinationTokenAddress,
            _expectedAmount,
            _timelock
        );
        return swapId;
    }
    // Deposit tokens for the swap (called by the initiator)
    function depositTokens(bytes32 _swapId) external {
        SwapRequest storage swap = swapRequests[_swapId];
        require(swap.initiator == msg.sender, "Not the swap initiator");
        require(swap.isActive, "Swap is not active");
        require(!swap.isDeposited, "Tokens already deposited");
        require(block.timestamp < swap.timelock, "Swap has expired");
        IERC20 token = IERC20(swap.tokenAddress);
        require(token.transferFrom(msg.sender, address(this), swap.amount), "Token transfer failed");
        swap.isDeposited = true;
        emit TokensDeposited(_swapId, msg.sender, swap.amount);
    }
}