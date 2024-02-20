// SPDX-LICENSE-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {console} from "forge-std/Test.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function createSubscriptionUsingConfig() public returns(uint64) {
        HelperConfig helper = new HelperConfig();
        (,,address vrfCoordinator,,,,) = helper.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint64) {
        // Create a subscription
        console.log("Creating a subscription on chain :", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ", subId);    
        console.log("please update the subscription ID in the HelperConfig contract");
        return subId;
    }

    function run() external returns(uint64)  {
        // Create a subscription
        return createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script {

    uint96 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helper = new HelperConfig();
        (
            ,
            ,address vrfCoordinator
            ,
            , uint64 subId
            ,
            ,address linkToken
        ) = helper.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address linkToken) public {
        // Fund the subscription
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using Subscription ID: ", subId);
        console.log("Funding the subscription on chain :", block.chainid);
        if (block.chainid == 31337){ //Anvil

            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        // Fund the subscription
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumer(address vrfCoordinator, uint64 subId, address raffle) public {
        // Add a consumer
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using Subscription ID: ", subId);
        console.log("Adding a consumer on chain :", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
        console.log("Consumer added");
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helper = new HelperConfig();
        (
            ,
            ,address vrfCoordinator
            ,
            , uint64 subId
            ,
            ,
        ) = helper.activeNetworkConfig();
        addConsumer(vrfCoordinator, subId, raffle); 
    }
    function run() external {
        // Add a consumer
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

    }
}