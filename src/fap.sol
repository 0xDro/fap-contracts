// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
            // Refund current player since game is over
            (bool refunded, ) = msg.sender.call{value: msg.value}("");
            require(refunded, "Failed to refund player");
            return;
        }

        // Continue game
        uint256 newWaitTime = calculateWaitTime(msg.value);
        _setPlayState(newWaitTime);
    }

    function _handleWin() private {
        address winner = lastPlayer;
        uint256 prize = address(this).balance;

        _setEndGameState();

        (bool sent, ) = winner.call{value: prize}("");
        require(sent, "Failed to send ETH");

        emit GameWon(winner, prize);
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
        uint256 minLogValue = 9210340372; // ln(0.0001) * 1e9
        uint256 maxLogValue = 2302585093; // ln(10) * 1e9

        // Convert deposit amount to a decimal for log calculation
        // We multiply by 1e9 to maintain precision
        uint256 depositInEth = (depositAmount * 1e9) / 1 ether;
        uint256 depositLogValue = _ln(depositInEth);

        // Linear interpolation between log values
        uint256 timeRange = MAX_WAIT_TIME - MIN_WAIT_TIME;
        uint256 logRange = minLogValue - maxLogValue; // Note: min is larger than max for negative logs
        uint256 waitTime = MAX_WAIT_TIME -
            (((minLogValue - depositLogValue) * timeRange) / logRange);

        return waitTime;
    }

    function _ln(uint256 x) private pure returns (uint256) {
        // Scaled by 1e9
        require(x > 0, "Log of zero");

        // Handle numbers less than 1e9 (less than 1.0)
        if (x < 1e9) {
            // For numbers less than 1, we use ln(x) = -ln(1/x)
            uint256 inverse = (1e18) / x;
            return 2302585093 - _ln(inverse / 1e9); // ln(10) * 1e9
        }

        uint256 result = 0;
        uint256 y = x;

        while (y >= 1e9) {
            result += 2302585093; // ln(10) * 1e9
            y /= 10;
        }

        y = y * 1e9 - 1e9;

        // Taylor series for ln(1+x)
        uint256 term = y;
        result += term;

        for (uint256 i = 2; i <= 10; i++) {
            term = (term * y) / (1e9 * i);
            if (i % 2 == 1) {
                result += term;
            } else {
                result -= term;
            }
        }

        return result;
    }

    receive() external payable {}
}
