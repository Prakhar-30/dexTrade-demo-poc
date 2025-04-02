// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Chain1SwapInitiator is Ownable {
    // Notifier contract address
    address public notifierAddress;
    
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
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Set the notifier contract address
     * @param _notifierAddress Address of the notifier contract
     */
    function setNotifierAddress(address _notifierAddress) external onlyOwner {
        notifierAddress = _notifierAddress;
    }
    
    /**
     * @dev Initiate a new swap request
     * @param _tokenAddress Address of the token on Chain1
     * @param _amount Amount of tokens to swap
     * @param _receivingAddress User's address on Chain2
     * @param _destinationTokenAddress Address of the token on Chain2
     * @param _expectedAmount Expected amount of tokens to receive
     * @param _timelock Time after which the swap request expires
     * @return swapId Unique identifier for the swap request
     */
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
        
        // Generate unique swap ID
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
        
        // Create swap request
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
        
        // Store swap request
        swapRequests[swapId] = newSwap;
        
        // Emit event for the notifier
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
    
    /**
     * @dev Deposit tokens for a swap
     * @param _swapId ID of the swap request
     */
    function depositTokens(bytes32 _swapId) external {
        SwapRequest storage swap = swapRequests[_swapId];
        
        require(swap.initiator == msg.sender, "Not the swap initiator");
        require(swap.isActive, "Swap is not active");
        require(!swap.isDeposited, "Tokens already deposited");
        require(block.timestamp < swap.timelock, "Swap has expired");
        
        // Transfer tokens from user to this contract
        IERC20 token = IERC20(swap.tokenAddress);
        require(token.transferFrom(msg.sender, address(this), swap.amount), "Token transfer failed");
        
        // Update swap status
        swap.isDeposited = true;
        
        // Emit event for the notifier
        emit TokensDeposited(_swapId, msg.sender, swap.amount);
    }
    
    /**
     * @dev Complete a swap (called by the notifier or reactive contract)
     * @param _swapId ID of the swap request
     */
    function completeSwap(bytes32 _swapId) external {
        require(msg.sender == notifierAddress, "Only notifier can complete swap");
        
        SwapRequest storage swap = swapRequests[_swapId];
        require(swap.isActive, "Swap is not active");
        require(swap.isDeposited, "Tokens not deposited");
        require(block.timestamp < swap.timelock, "Swap has expired");
        
        // Update swap status
        swap.isActive = false;
        
        // Emit completion event
        emit SwapCompleted(_swapId, swap.initiator);
        
        // Note: Actual token transfer to the user's address happens on Chain2
    }
    
    /**
     * @dev Cancel a swap request (only initiator can cancel)
     * @param _swapId ID of the swap request
     */
    function cancelSwap(bytes32 _swapId) external {
        SwapRequest storage swap = swapRequests[_swapId];
        
        require(swap.initiator == msg.sender, "Not the swap initiator");
        require(swap.isActive, "Swap is not active");
        
        // If tokens were deposited, return them to the initiator
        if (swap.isDeposited) {
            IERC20 token = IERC20(swap.tokenAddress);
            require(token.transfer(swap.initiator, swap.amount), "Token transfer failed");
            emit TokensWithdrawn(_swapId, swap.initiator, swap.amount);
        }
        
        // Update swap status
        swap.isActive = false;
        
        // Emit cancellation event
        emit SwapCancelled(_swapId, msg.sender);
    }
    
    /**
     * @dev Withdraw tokens after timelock expires (safety mechanism)
     * @param _swapId ID of the swap request
     */
    function withdrawExpiredSwap(bytes32 _swapId) external {
        SwapRequest storage swap = swapRequests[_swapId];
        
        require(swap.initiator == msg.sender, "Not the swap initiator");
        require(swap.isActive, "Swap is not active");
        require(swap.isDeposited, "Tokens not deposited");
        require(block.timestamp >= swap.timelock, "Swap has not expired yet");
        
        // Transfer tokens back to initiator
        IERC20 token = IERC20(swap.tokenAddress);
        require(token.transfer(swap.initiator, swap.amount), "Token transfer failed");
        
        // Update swap status
        swap.isActive = false;
        
        // Emit events
        emit TokensWithdrawn(_swapId, swap.initiator, swap.amount);
        emit SwapCancelled(_swapId, msg.sender);
    }
    
    /**
     * @dev Get swap request details
     * @param _swapId ID of the swap request
     * @return Swap request details
     */
    function getSwapDetails(bytes32 _swapId) external view returns (
        address initiator,
        address tokenAddress,
        uint256 amount,
        address receivingAddress,
        address destinationTokenAddress,
        uint256 expectedAmount,
        uint256 timelock,
        bool isActive,
        bool isDeposited
    ) {
        SwapRequest memory swap = swapRequests[_swapId];
        return (
            swap.initiator,
            swap.tokenAddress,
            swap.amount,
            swap.receivingAddress,
            swap.destinationTokenAddress,
            swap.expectedAmount,
            swap.timelock,
            swap.isActive,
            swap.isDeposited
        );
    }
}