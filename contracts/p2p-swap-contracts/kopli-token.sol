// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract KopliToken is ERC20 {
    constructor() ERC20("KopliToken", "KTK") {
        // Mint 100 tokens to the deployer (using 18 decimals as is standard)
        _mint(msg.sender, 100 * 10**18);
    }
}

//kopli-token-address: 0x20D8D70AF616471Ff6e651f89Ff2cA1cA3fb5010  (sepolia)usdt=0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0