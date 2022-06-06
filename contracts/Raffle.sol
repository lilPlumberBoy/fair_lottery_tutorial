// Raffle
//Enter Lottery
// Pick a random winner
// Winner to be selected every x min
// Chainlink Oracle -> randomness, automated executon (Chainlink keepers)

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// to allow this import we run:
// yarn add --dev @chainlink/contracts
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

// custom Error Code to save gas
error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();

// This contract is VRFConsumerBaseV2 from @chainlink/contracts so we can use fulfillRandomWords()
contract Raffle is VRFConsumerBaseV2 {
    /* State Variables */
    address payable[] private s_players; // s_ showing it is storage
    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    // all caps and __ for constants
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    //  Lottery Variables
    address private s_recentWinner;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    // the vrfCoordinatorV2 is the address of the contract that does the random number verification
    // Not sure exactly how this is working, passing the address to a contructor of the chainlink contract?
    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        // initiate VRF interface with our Coordinator address
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        // require msg.value > i_e ntranceFee
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender)); // need to convert to payable address here
        // Events
        // Whenever updateing a dynamic data structure you should fire an event
        // Name events with function name reversed
        emit RaffleEnter(msg.sender);
    }

    function requestRandomWinner() external {
        // Request the random number
        // Once we get it, do something
        // 2 transaction process
        // returns an uint256 deescribing the request
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // maximum price you are willing to pay for gas
            i_subscriptionId, // subscribition id used for funding our request
            REQUEST_CONFIRMATIONS, // how many confirmations we should wait before responding
            i_callbackGasLimit, // how much gas used for the callback (how much computation we can afford)
            NUM_WORDS // how many randomw words we want
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /*requestId*/ // can comment out argument of function if not used
        uint256[] memory randomWords
    ) internal override {
        // Get the random number
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        // Get the winner
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        // Pay the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // require(success)
        if (!success) {
            revert Raffle__TransferFailed(); //undo state changes
        }
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPLayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
