// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import 'lib/reactive-lib/src/interfaces/ISubscriptionService.sol';
import 'lib/reactive-lib/src/interfaces/IReactive.sol';

contract RSC is AbstractReactive {
    uint256 private constant ORIGIN_CHAIN_ID = 5318008;
    uint256 private constant DESTINATION_CHAIN_ID = 5318008;
    uint64 private constant CALLBACK_GAS_LIMIT = 3000000;
    uint256 private constant TOKENS_DEPOSITED_TOPIC0 = 0xa5acfcde5118075b17c34a71ac1feff954a6696141900041d1da05095063ae65;
    uint256 private constant SWAP_ACKNOWLEDGED_TOPIC0 = 0xaee1ad0ac63ac6c2226b014e31be38087ec2ba09fe3d48d14b7fffa5f170f1fc;
    
    address private immutable swap_closer_contract;
    address private reciever;
    
    event SubscriptionStatus(bool success);

    constructor(address Origin_Contract) {
        swap_closer_contract = Origin_Contract;
        
        if (!vm) {
            try service.subscribe(
                ORIGIN_CHAIN_ID,
                Origin_Contract,
                TOKENS_DEPOSITED_TOPIC0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            ) {
                emit SubscriptionStatus(true);
            } catch {
                emit SubscriptionStatus(false);
            }

            try service.subscribe(
                ORIGIN_CHAIN_ID,
                Origin_Contract,
                SWAP_COMPLETED_TOPIC0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            ) {
                emit SubscriptionStatus(true);
            } catch {
                emit SubscriptionStatus(false);
            }
        }
    }

    function react(LogRecord calldata log) external override vmOnly {
        require(log.chain_id == ORIGIN_CHAIN_ID, "Wrong chain");
        require(log._contract == swap_closer_contract, "Wrong contract");
        if (log.topic_0 == SWAP_ACKNOWLEDGED_TOPIC0) {
                reciever = address(uint160(log.topic_3));
            }
        else if (log.topic_0 == TOKENS_DEPOSITED_TOPIC0) {
            bytes memory payload_callback = abi.encodeWithSignature(
            "completeSwap(bytes32)",
            log.topic_1,
            );
            emit Callback(
            DESTINATION_CHAIN_ID,
            swap_closer_contract,
            CALLBACK_GAS_LIMIT,
            payload_callback
            );
         }
    }
}