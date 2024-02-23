// SPDX-License-Identifier: MIT


pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


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

    modifier rollForwardInterval() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier payEntranceFee() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

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
            linkToken,
        ) = helper.activeNetworkConfig();
    
    }   

    function testRaffleInitialisesProperly() public {
        address payable[] memory players = raffle.getPlayers();
        assert(uint(raffle.getRaffleState()) == uint(Raffle.RaffleState.OPEN));
        assertEq(players.length, 0);
        assert(raffle.getRecentWinner() == address(0));
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

    function testPlayerIsCorrectlyAddedToRaffle() public payEntranceFee {
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

    function testRaffleRevertsWhenNotOpen() public payEntranceFee rollForwardInterval {
        // Act
        raffle.performUpkeep("");

        // Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////
    // checkUpkeep //
    /////////////////

    function testCheckUpkeepReturnsTrueWhenAllConditionsMet() public payEntranceFee rollForwardInterval {
        // Arrange
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenTimeHasNotPassed() public payEntranceFee {
        // Arrange
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenNotOpen() public payEntranceFee rollForwardInterval {
        // Arrange
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenNoPlayers() public rollForwardInterval {
        // Arrange
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    ////////////////////
    // performUpkeep  //
    ////////////////////

    function testPerformUpkeepRunsWhenUpkeepNeeded() public payEntranceFee rollForwardInterval {
        // Arrange
        // Act
        raffle.performUpkeep("");
        // Assert
        assertEq(uint(raffle.getRaffleState()), uint(Raffle.RaffleState.CALCULATING));
    }

    function testPerformUpkeepRevertsWhenUpkeepNotNeeded() public {
        // Arrange
        uint256 currentBal = 0;
        uint256 playersLength = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBal, playersLength, raffleState)
        );
        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepEmitsRequestIdProperly() public payEntranceFee rollForwardInterval {
        // Arrange
        // Act
        vm.recordLogs();
        // vm.expectEmit(true, false, false, false, address(raffle));
        // emit Raffle.RequestedRaffleWinner(1);
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        Raffle.RaffleState state = raffle.getRaffleState();
        assert(requestId != 0);
        assertEq(uint(state), uint(Raffle.RaffleState.CALCULATING));
    }

    ////////////////////////
    // fulfillRandomness  //
    ////////////////////////

    modifier skipFork() {
        if(block.chainid != 31337) {
        }
        else{
            _;
        }
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) 
        public 
        skipFork
        payEntranceFee 
        rollForwardInterval {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsWinnings()
        public
        skipFork
        payEntranceFee
        rollForwardInterval {
        // Arrange
        uint256 additionalEntrants = 8;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);   
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = address(raffle).balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 requestId = uint256(logs[1].topics[1]);
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));

        // Assert
        assert(uint256(raffle.getRaffleState()) == uint256(Raffle.RaffleState.OPEN));
        assert(raffle.getRecentWinner() != address(0));
        assertEq(raffle.getPlayers().length, 0);
        assertEq(raffle.getLastTimestamp(), block.timestamp);
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);

    }


}