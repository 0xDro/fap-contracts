// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract Fap is ReentrancyGuard {
    // Constants for deposit limits and time windows
    uint256 public constant MIN_DEPOSIT = 0.0001 ether;
    uint256 public constant MAX_DEPOSIT = 10 ether;
    uint256 public constant MAX_WAIT_TIME = 3600; // 1 hour in seconds
    uint256 public constant MIN_WAIT_TIME = 60; // 1 minute in seconds
    uint256 public constant INITIAL_POOL = 1 ether;

    // Game state variables
    uint256 public lastPlayedTime;
    address public lastPlayer;
    uint256 public lastDepositAmount;
    uint256 public gamesPlayed;
    uint256 public numberOfPlays;
    bool public gameInProgress;

    event GameStarted(address indexed starter, uint256 initialPool);
    event GameWon(address indexed winner, uint256 prize);
    event Played(address indexed player, uint256 amount, uint256 waitTime);

    constructor() {}

    function startGame() external payable {
        require(!gameInProgress, "Game already in progress");
        gameInProgress = true;
        gamesPlayed++;
        emit GameStarted(msg.sender, msg.value);
    }

    function play() external payable nonReentrant {
        require(gameInProgress, "Game not started");
        require(msg.value >= MIN_DEPOSIT, "Deposit too small");
        require(msg.value <= MAX_DEPOSIT, "Deposit too large");

        // If this is the first play of the game
        if (lastPlayedTime == 0) {
            _setFirstPlayState();
            return;
        }

        // Check if previous player won based on their deposit amount and wait time
        uint256 previousWaitTime = calculateWaitTime(lastDepositAmount);
        if (block.timestamp >= lastPlayedTime + previousWaitTime) {
            _handleWin();
            return;
        }

        // Continue game
        uint256 newWaitTime = calculateWaitTime(msg.value);
        _setPlayState(newWaitTime);
    }

    function _handleWin() private {
        // Save current contract balance before new deposit
        uint256 prizeAmount = address(this).balance - msg.value;
        address winner = lastPlayer;

        // Reset game state before transfers to prevent reentrancy
        _setEndGameState();

        // First refund current player
        (bool refunded, ) = msg.sender.call{value: msg.value}("");
        require(refunded, "Failed to refund player");

        // Then send prize to winner
        (bool sent, ) = winner.call{value: prizeAmount}("");
        require(sent, "Failed to send prize");

        emit GameWon(winner, prizeAmount);
    }

    function _setFirstPlayState() private {
        lastPlayedTime = block.timestamp;
        lastPlayer = msg.sender;
        lastDepositAmount = msg.value;
        numberOfPlays = 1;
        emit Played(msg.sender, msg.value, calculateWaitTime(msg.value));
    }

    function _setEndGameState() private {
        lastPlayedTime = 0;
        lastPlayer = address(0);
        lastDepositAmount = 0;
        numberOfPlays = 0;
        gameInProgress = false;
    }

    function _setPlayState(uint256 waitTime) private {
        lastPlayedTime = block.timestamp;
        lastPlayer = msg.sender;
        lastDepositAmount = msg.value;
        numberOfPlays++;
        emit Played(msg.sender, msg.value, waitTime);
    }

    function calculateWaitTime(
        uint256 depositAmount
    ) public pure returns (uint256) {
        // Using natural log for scaling
        // Scale from ln(0.0001) to ln(10) to MAX_WAIT_TIME to MIN_WAIT_TIME
        int256 minLogValue = -9210340372; // ln(0.0001) * 1e9 (negative since it's less than 1)
        int256 maxLogValue = 2302585093; // ln(10) * 1e9

        // Handle edge cases first to avoid rounding errors
        if (depositAmount >= MAX_DEPOSIT) return MIN_WAIT_TIME;
        if (depositAmount <= MIN_DEPOSIT) return MAX_WAIT_TIME;

        // Convert deposit amount to a decimal for log calculation
        // We multiply by 1e18 to match Solady's precision
        int256 depositInEth = int256((depositAmount * 1e18) / 1 ether);

        // Get log value and scale down to 1e9
        int256 depositLogValue = FixedPointMathLib.lnWad(depositInEth) / 1e9;

        // Linear interpolation between log values
        int256 logRange = maxLogValue - minLogValue;
        int256 timeRange = int256(MAX_WAIT_TIME - MIN_WAIT_TIME);

        // Calculate wait time using linear interpolation
        int256 normalizedPosition = ((depositLogValue - minLogValue) *
            timeRange) / logRange;
        uint256 waitTime = uint256(int256(MAX_WAIT_TIME) - normalizedPosition);

        // Ensure bounds
        if (waitTime < MIN_WAIT_TIME) return MIN_WAIT_TIME;
        if (waitTime > MAX_WAIT_TIME) return MAX_WAIT_TIME;

        return waitTime;
    }

    receive() external payable {}
}
