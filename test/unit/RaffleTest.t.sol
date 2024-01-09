// SPDX-Licencse-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    //bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    address public DUMMY = makeAddr("dummy");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator, ,
            //gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier skipFork() {
        if(block.chainid != 31337){
            return;
        }
        _;
    }

    modifier raffleEnteredAndTimePassed(address _playerAddress){
        vm.prank(_playerAddress);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier intervalPassed(){
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOppenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    function testRaffleRevertsWhenNotPayedEnough() public {
        // Arrange
        vm.startPrank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        // Assert
        raffle.enterRaffle{value: 0 ether}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCannotEnterWhenRaffleIsNotOpen() public raffleEnteredAndTimePassed(PLAYER) {
        //After this it should be in calculating state
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }


    function testCheckUpkeepReturnsFalseIfItHasNotEnoughBalance() public intervalPassed {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public raffleEnteredAndTimePassed(PLAYER) {
        //Arrange
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseIfTimeNotPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsTrueIfAllParametersAreGood() public raffleEnteredAndTimePassed(PLAYER) {

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upkeepNeeded, true);
    }

    
    function testPerformUpkeepPutsContractInCalculatingStateAndEmitsRequestIdEvent() public raffleEnteredAndTimePassed(PLAYER) {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        assert(raffle.getRaffleState() == Raffle.RaffleState.Calculating);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2);
        assertEq(entries[1].topics[0], keccak256("RequestedRaffleWinner(uint256)"));
        assert(entries[1].topics[1] > 0);
    }

    function testPerformUpkeepCannotRunWhenIntervalNotPassed() public skipFork {
        
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, numPlayers, raffleState));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepCannotRunWhenContractStateIsNotOpen() public raffleEnteredAndTimePassed(PLAYER) skipFork {

        uint256 balance = entranceFee;
        uint256 numPlayers = 1;
        uint256 raffleState = 1;

        raffle.performUpkeep("");
        
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, numPlayers, raffleState));
        raffle.performUpkeep("");

    }

    // This is a fuzz test
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed(PLAYER) skipFork {
        // Arrange

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed(PLAYER) skipFork {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        assert(raffle.getNumberOfPlayers() == additionalEntrants + 1);
        assert(raffle.getRecentWinner() == address(0));

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        console.log("RequestId: %s", uint256(requestId));
        console.logBytes32(requestId);

        uint256 previousTimeStamp = raffle.getLastTimestamp();
        assertEq(previousTimeStamp, block.timestamp);

        uint256 prize = entranceFee * (additionalEntrants + 1);

        //vm.warp(block.timestamp + 1);
        //vm.roll(block.number + 1);

        // Pretend to be chainling VRF and pick random number
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getNumberOfPlayers() == 0);
        assert(previousTimeStamp <= raffle.getLastTimestamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);

    }

}
