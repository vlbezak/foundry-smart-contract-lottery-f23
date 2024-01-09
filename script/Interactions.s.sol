//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateVRFSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , address link, uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64 subscriptionId) {
        console.log("Creating VRF subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        console.log("Created subId: %s", subscriptionId);
        vm.stopBroadcast();
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundVRFSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address link,
        uint256 deployerKey
    ) public {
        console.log(
            "Funding VRF subscription: %s on chainId: %s",
            subscriptionId,
            block.chainid
        );
        console.log("Using VRFCoordinator: %s", vrfCoordinator);
        vm.startBroadcast(deployerKey);

        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
        }

        console.log("Funded subId: %s", subscriptionId);
        vm.stopBroadcast();
    }

    function run() external {
        return fundSubscriptionUsingConfig();
    }
}

contract AddVRFConsumer is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function addConsumerUsingConfig(address raffleAddress) public {
        console.log("Add Consumer: %s", raffleAddress);
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffleAddress, vrfCoordinator, subId, deployerKey);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log(
            "Add consumer: raffle: %s  vrfCoordinator: %s subId: %s ",
            raffle,
            vrfCoordinator,
            subId
        );
        console.log("On Chain: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        return addConsumerUsingConfig(raffleAddress);
    }
}
