// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import 'lib/reactive-lib/src/interfaces/ISubscriptionService.sol';
import 'lib/reactive-lib/src/interfaces/IReactive.sol';

contract RSC is AbstractReactive {
    uint256 private constant KOPLI_CHAIN_ID = 5318008;
    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint64 private constant CALLBACK_GAS_LIMIT = 3000000;
    uint256 private constant TOKENS_DEPOSITED_TOPIC0 = 0xa5acfcde5118075b17c34a71ac1feff954a6696141900041d1da05095063ae65;
    uint256 private constant SWAP_INITIATED_TOPIC0 = 0x0c45b670149883c08347a208a2779a19ef16e04bbf819c883ff56f7a64f34611;
    
    address private immutable swap_closer_contract;
    address private immutable swap_initiator_contract;
    
    event SubscriptionStatus(bool success);

    constructor(address swap_closer, address swap_initiator) {
        swap_initiator_contract= swap_initiator;
        swap_closer_contract = swap_closer;

        if (!vm) {
            try service.subscribe(
                KOPLI_CHAIN_ID,
                swap_closer_contract,
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
                SEPOLIA_CHAIN_ID,
                swap_initiator_contract,
                SWAP_INITIATED_TOPIC0,
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
        require(log.chain_id == SEPOLIA_CHAIN_ID, "Wrong chain");
        require(log._contract == swap_initiator_contract, "Wrong contract");
        if (log.topic_0 == SWAP_INITIATED_TOPIC0) {
                bytes memory payload_callback = abi.encodeWithSignature(
                    "updateReceivingAddress(address,address)",
                    address(0),
                    address(uint160(log.topic_3))
                    );
                emit Callback(
                KOPLI_CHAIN_ID,
                swap_closer_contract,
                CALLBACK_GAS_LIMIT,
                payload_callback
                );
            }
        if (log.topic_0 == TOKENS_DEPOSITED_TOPIC0) {
            bytes memory payload_callback = abi.encodeWithSignature(
                "completeSwap(address,bytes32)",
                address(0),
                log.topic_1
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