// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {FundSubscription} from "./Interactions.s.sol";
import {AddConsumer} from "./Interactions.s.sol";

pragma solidity ^0.8.18;



contract DeployRaffle is Script {

    uint16 private constant NUM_WORDS = 2;

    function run () external returns(Raffle, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        (uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address linkToken, 
        uint256 deployerKey) = helper.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubscription createSub = new CreateSubscription();
            subscriptionId = createSub.createSubscription(vrfCoordinator, deployerKey);

            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(vrfCoordinator, subscriptionId, linkToken, deployerKey);
            
        }

        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, NUM_WORDS);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCoordinator, subscriptionId,address(raffle), deployerKey);
        return (raffle, helper);
    }
}