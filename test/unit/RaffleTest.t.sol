// SPDX-License-Identifier: MIT


pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";


contract RaffleTest is Test {

    Raffle raffle;
    HelperConfig helper;
    address public PLAYER = makeAddr("PLAYER");
    uint256 public STARTING_USER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helper) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkToken
        ) = helper.activeNetworkConfig();
    
    }   

    function testRaffleInitialisesProperly() public {
        address payable[] memory players = raffle.getPlayers();
        assert(uint(raffle.getRaffleState()) == uint(Raffle.RaffleState.OPEN));
        assertEq(players.length, 0);
    }

    //////////////////
    // enterRaffle //
    /////////////////
    function testRaffleRevertsWhenNotEnoughEthSent() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        // Act
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testPlayerIsCorrectlyAddedToRaffle() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address payable[] memory players = raffle.getPlayers();
        console.log("players.length", players.length);
        assertEq(players.length, 1);
        assertEq(players[0], PLAYER);
    }

    function testEmitsEnteredRaffleEvent() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.EnteredRaffle(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
    }

    function testRaffleRevertsWhenNotOpen() public {
        // Arrange
        // Act
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep();


        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

}