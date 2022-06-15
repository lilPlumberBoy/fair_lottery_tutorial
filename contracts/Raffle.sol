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
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

// custom Error Code to save gas
error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

// This contract is VRFConsumerBaseV2 from @chainlink/contracts so we can use fulfillRandomWords()
/** @title A sample Raffle Contract
 * @author Patrick Collins
 * @notice This contract is for creating an untamperable decentralized smart contract.
 * @dev This implements Clainlink VRF v2 and Chainlink Keepers.
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    } // This is really doing uint256 0 = OPEN, 1 = CALCULATING

    /* State Variables */
    address payable[] private s_players; // s_ showing it is storage
    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane; // i_ immutable as it will never change
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    // all caps and __ for constants
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    //  Lottery Variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    // the vrfCoordinatorV2 is the address of the contract that does the random number verification
    // Not sure exactly how this is working, passing the address to a contructor of the chainlink contract?
    constructor(
        address vrfCoordinatorV2, // contract (will need to mock to run locally)
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        // initiate VRF interface with our Coordinator address
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    /* Functions */

    function enterRaffle() public payable {
        // require msg.value > i_e ntranceFee
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender)); // need to convert to payable address here
        // Events
        // Whenever updateing a dynamic data structure you should fire an event
        // Name events with function name reversed
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for the 'upkeepNeeded' to return true
     * having bytes calldata allows us to specify whatever we want when calling this function
     * we can even call other functions with this
     * The following should be true in order to return true:
     * 1. Our time interval should have passed
     * 2. The lottery should have at least 1 player, and have some ETH
     * 3. Our subscription is funded with LINK
     * 4. Lottery should be in an open state
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        // Request the random number
        // Once we get it, do something
        // 2 transaction process
        // returns an uint256 describing the request
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
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
        s_raffleState = RaffleState.OPEN;
        // reset players array to 0
        s_players = new address payable[](0);
        // reset timestamp
        s_lastTimeStamp = block.timestamp;
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

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    // can be pure because it can be read from the bytecode not storage
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
