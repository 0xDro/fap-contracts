// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Fap} from "../src/fap.sol";

contract FapTest is Test {
    Fap public fap;
    uint256 constant MIN_WAIT_TIME = 60;
    uint256 constant MAX_WAIT_TIME = 3600;

    function setUp() public {
        fap = new Fap();
    }

    function test_calculateWaitTime_MinDeposit() public {
        uint256 waitTime = fap.calculateWaitTime(0.0001 ether);
        assertEq(
            waitTime,
            MAX_WAIT_TIME,
            "Min deposit should result in max wait time"
        );
    }

    function test_calculateWaitTime_MaxDeposit() public {
        uint256 waitTime = fap.calculateWaitTime(10 ether);
        assertEq(
            waitTime,
            MIN_WAIT_TIME,
            "Max deposit should result in min wait time"
        );
    }

    function test_calculateWaitTime_MidDeposit() public {
        uint256 waitTime = fap.calculateWaitTime(1 ether);
        // 1 ETH should give a wait time somewhere between min and max
        assertTrue(
            waitTime > MIN_WAIT_TIME,
            "Wait time should be greater than min"
        );
        assertTrue(
            waitTime < MAX_WAIT_TIME,
            "Wait time should be less than max"
        );
    }

    function test_calculateWaitTime_Scaling() public {
        uint256[] memory deposits = new uint256[](4);
        deposits[0] = 0.0001 ether; // MIN_DEPOSIT
        deposits[1] = 0.1 ether;
        deposits[2] = 1 ether;
        deposits[3] = 10 ether; // MAX_DEPOSIT

        for (uint256 i = 1; i < deposits.length; i++) {
            uint256 previousWait = fap.calculateWaitTime(deposits[i - 1]);
            uint256 currentWait = fap.calculateWaitTime(deposits[i]);
            assertTrue(
                previousWait > currentWait,
                "Higher deposits should have lower wait times"
            );
        }
    }

    function test_calculateWaitTime_FuzzDeposits(uint256 deposit) public {
        // Bound the deposit between MIN_DEPOSIT and MAX_DEPOSIT
        deposit = bound(deposit, 0.0001 ether, 10 ether);

        uint256 waitTime = fap.calculateWaitTime(deposit);

        // Check bounds
        assertTrue(
            waitTime >= MIN_WAIT_TIME,
            "Wait time should not be less than MIN_WAIT_TIME"
        );
        assertTrue(
            waitTime <= MAX_WAIT_TIME,
            "Wait time should not exceed MAX_WAIT_TIME"
        );
    }

    function test_calculateWaitTime_Table() public {
        uint256[] memory deposits = new uint256[](5);
        deposits[0] = 0.0001 ether; // MIN_DEPOSIT
        deposits[1] = 0.01 ether;
        deposits[2] = 0.1 ether;
        deposits[3] = 1 ether;
        deposits[4] = 10 ether; // MAX_DEPOSIT

        console.log("Deposit (ETH) | Wait Time (seconds)");
        console.log("--------------------------------");

        for (uint256 i = 0; i < deposits.length; i++) {
            uint256 waitTime = fap.calculateWaitTime(deposits[i]);
            console.log(
                string(
                    abi.encodePacked(
                        deposits[i] / 1 ether,
                        " ETH | ",
                        waitTime,
                        "s"
                    )
                )
            );
        }
    }

    function testFuzz_WaitTimeMonotonicallyDecreases(
        uint256 deposit1,
        uint256 deposit2
    ) public {
        // Convert to wei first to avoid precision loss
        uint256 minDepositWei = 0.0001 ether;
        uint256 maxDepositWei = 10 ether;

        // Ensure deposits are properly bounded and ordered
        deposit1 = bound(deposit1, minDepositWei, maxDepositWei);
        deposit2 = bound(deposit2, minDepositWei, maxDepositWei);

        // Ensure deposits are sufficiently different to avoid rounding issues
        if (deposit1 > deposit2) {
            (deposit1, deposit2) = (deposit2, deposit1);
        }
        // Ensure at least 1% difference between deposits
        if (deposit2 - deposit1 < deposit1 / 100) {
            deposit2 = deposit1 + deposit1 / 100;
            if (deposit2 > maxDepositWei) {
                deposit2 = maxDepositWei;
                deposit1 = deposit2 - deposit2 / 100;
            }
        }

        uint256 wait1 = fap.calculateWaitTime(deposit1);
        uint256 wait2 = fap.calculateWaitTime(deposit2);

        assertTrue(
            wait1 > wait2,
            string(
                abi.encodePacked(
                    "Wait time should decrease as deposit increases: ",
                    "deposit1=",
                    vm.toString(deposit1),
                    " wei, wait1=",
                    vm.toString(wait1),
                    "s, deposit2=",
                    vm.toString(deposit2),
                    " wei, wait2=",
                    vm.toString(wait2),
                    "s"
                )
            )
        );
    }

    function testFuzz_WaitTimeWithinBounds(uint256 deposit) public {
        deposit = bound(deposit, 0.0001 ether, 10 ether);
        uint256 waitTime = fap.calculateWaitTime(deposit);

        assertTrue(
            waitTime >= MIN_WAIT_TIME && waitTime <= MAX_WAIT_TIME,
            "Wait time must be within bounds"
        );
    }

    function testFuzz_ExtremeValues(uint256 deposit) public {
        uint256 minDepositWei = 0.0001 ether;
        uint256 maxDepositWei = 10 ether;

        // Test minimum deposit exactly
        uint256 waitTimeMin = fap.calculateWaitTime(minDepositWei);
        assertEq(
            waitTimeMin,
            MAX_WAIT_TIME,
            string(
                abi.encodePacked(
                    "Minimum deposit should give maximum wait time: waitTime=",
                    vm.toString(waitTimeMin),
                    "s"
                )
            )
        );

        // Test maximum deposit exactly
        uint256 waitTimeMax = fap.calculateWaitTime(maxDepositWei);
        assertEq(
            waitTimeMax,
            MIN_WAIT_TIME,
            string(
                abi.encodePacked(
                    "Maximum deposit should give minimum wait time: waitTime=",
                    vm.toString(waitTimeMax),
                    "s"
                )
            )
        );

        // Test near minimum (within 1% of min deposit)
        uint256 nearMin = bound(
            deposit,
            minDepositWei,
            (minDepositWei * 101) / 100
        );
        uint256 waitTimeNearMin = fap.calculateWaitTime(nearMin);
        assertTrue(
            waitTimeNearMin >= (MAX_WAIT_TIME * 95) / 100,
            string(
                abi.encodePacked(
                    "Near min deposit should have near max wait time: deposit=",
                    vm.toString(nearMin),
                    " wei, waitTime=",
                    vm.toString(waitTimeNearMin),
                    "s"
                )
            )
        );

        // Test near maximum (within 1% of max deposit)
        uint256 nearMax = bound(
            deposit,
            (maxDepositWei * 99) / 100,
            maxDepositWei
        );
        uint256 waitTimeNearMax = fap.calculateWaitTime(nearMax);

        // Allow wait time to be up to 5 seconds above MIN_WAIT_TIME
        assertTrue(
            waitTimeNearMax <= MIN_WAIT_TIME + 5,
            string(
                abi.encodePacked(
                    "Near max deposit should have near min wait time (<=65s): deposit=",
                    vm.toString(nearMax),
                    " wei, waitTime=",
                    vm.toString(waitTimeNearMax),
                    "s"
                )
            )
        );
    }

    function testFuzz_Continuity(uint256 deposit1, uint256 deposit2) public {
        // Test that similar deposits result in similar wait times
        deposit1 = bound(deposit1, 0.0001 ether, 10 ether);
        // Bound deposit2 to be within 0.1% of deposit1
        uint256 maxDiff = deposit1 / 1000;
        deposit2 = bound(
            deposit2,
            deposit1 > maxDiff ? deposit1 - maxDiff : 0.0001 ether,
            deposit1 + maxDiff > 10 ether ? 10 ether : deposit1 + maxDiff
        );

        uint256 wait1 = fap.calculateWaitTime(deposit1);
        uint256 wait2 = fap.calculateWaitTime(deposit2);

        // Calculate the maximum expected difference in wait times (1% of the range)
        uint256 maxWaitDiff = (MAX_WAIT_TIME - MIN_WAIT_TIME) / 100;

        assertTrue(
            absDiff(wait1, wait2) <= maxWaitDiff,
            "Similar deposits should have similar wait times"
        );
    }

    // Helper function to calculate absolute difference
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    // Game state tests
    function test_InitialState() public {
        assertEq(fap.lastPlayedTime(), 0);
        assertEq(fap.lastPlayer(), address(0));
        assertEq(fap.lastDepositAmount(), 0);
        assertEq(fap.gamesPlayed(), 0);
        assertEq(fap.numberOfPlays(), 0);
        assertFalse(fap.gameInProgress());
    }

    function test_StartGame() public {
        vm.deal(address(this), 1 ether);
        fap.startGame{value: 1 ether}();

        assertTrue(fap.gameInProgress());
        assertEq(fap.gamesPlayed(), 1);
        assertEq(address(fap).balance, 1 ether);
    }

    function testFail_StartGameTwice() public {
        fap.startGame();
        fap.startGame();
    }

    function test_Play_FirstPlay() public {
        // Start game
        fap.startGame();

        // First play
        vm.deal(address(this), 1 ether);
        fap.play{value: 1 ether}();

        assertEq(fap.lastPlayer(), address(this));
        assertEq(fap.lastDepositAmount(), 1 ether);
        assertEq(fap.numberOfPlays(), 1);
        assertTrue(fap.lastPlayedTime() > 0);
    }

    function test_Play_SecondPlay() public {
        // Start game
        fap.startGame();

        // First play
        vm.deal(address(this), 1 ether);
        fap.play{value: 1 ether}();

        // Second play from different address
        address player2 = address(0x2);
        vm.deal(player2, 2 ether);
        vm.prank(player2);
        fap.play{value: 2 ether}();

        assertEq(fap.lastPlayer(), player2);
        assertEq(fap.lastDepositAmount(), 2 ether);
        assertEq(fap.numberOfPlays(), 2);
    }

    function test_Play_Win() public {
        // Start game with initial balance
        vm.deal(address(this), 1 ether);
        fap.startGame{value: 1 ether}();

        // First play
        address player1 = address(0x1);
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        fap.play{value: 1 ether}();

        // Record initial balances
        uint256 initialBalance1 = player1.balance;
        address player2 = address(0x2);
        vm.deal(player2, 1 ether);
        uint256 initialBalance2 = player2.balance;

        // Wait for more than the wait time
        uint256 waitTime = fap.calculateWaitTime(1 ether);
        vm.warp(block.timestamp + waitTime + 1);

        // Second play should trigger win for first player
        vm.prank(player2);
        fap.play{value: 1 ether}();

        // Calculate expected prize (total - 1% fee)
        uint256 totalPrize = 2 ether; // Initial 1 ETH + first play 1 ETH
        uint256 fee = (totalPrize * fap.FEE_PERCENTAGE()) / 100;
        uint256 expectedPrize = totalPrize - fee;

        // Check player1 won and got the prize minus fee
        assertEq(
            player1.balance,
            initialBalance1 + expectedPrize,
            "Winner should receive prize minus fee"
        );
        // Check player2 got refunded
        assertEq(
            player2.balance,
            initialBalance2,
            "Player2 should be refunded"
        );
        assertFalse(fap.gameInProgress(), "Game should be over");
        assertEq(fap.lastPlayedTime(), 0, "Last played time should be reset");
        assertEq(fap.lastPlayer(), address(0), "Last player should be reset");
    }

    function testFuzz_Play_ValidDeposits(uint256 deposit) public {
        deposit = bound(deposit, 0.0001 ether, 10 ether);

        fap.startGame();
        vm.deal(address(this), deposit);
        fap.play{value: deposit}();

        assertEq(fap.lastDepositAmount(), deposit);
    }

    function testFail_Play_TooSmallDeposit() public {
        fap.startGame();
        vm.deal(address(this), 0.00009 ether);
        fap.play{value: 0.00009 ether}();
    }

    function testFail_Play_TooLargeDeposit() public {
        fap.startGame();
        vm.deal(address(this), 11 ether);
        fap.play{value: 11 ether}();
    }

    function testFail_Play_GameNotStarted() public {
        vm.deal(address(this), 1 ether);
        fap.play{value: 1 ether}();
    }

    // Event tests
    event GameStarted(address indexed starter, uint256 initialPool);
    event GameWon(address indexed winner, uint256 prize);
    event Played(address indexed player, uint256 amount, uint256 waitTime);

    // Invariant tests
    function invariant_BalanceMatchesDeposits() public {
        // Balance should match the sum of deposits when game is in progress
        if (fap.gameInProgress()) {
            assertEq(address(fap).balance, fap.lastDepositAmount());
        } else {
            assertEq(address(fap).balance, 0);
        }
    }

    function invariant_ValidGameState() public {
        if (fap.gameInProgress()) {
            // During game
            if (fap.numberOfPlays() > 0) {
                assertTrue(
                    fap.lastPlayedTime() > 0,
                    "Last played time should be set"
                );
                assertTrue(
                    fap.lastDepositAmount() >= 0.0001 ether,
                    "Deposit should be >= MIN_DEPOSIT"
                );
                assertTrue(
                    fap.lastDepositAmount() <= 10 ether,
                    "Deposit should be <= MAX_DEPOSIT"
                );
            }
        } else {
            // Between games
            assertEq(fap.lastPlayedTime(), 0);
            assertEq(fap.lastPlayer(), address(0));
            assertEq(fap.lastDepositAmount(), 0);
            assertEq(fap.numberOfPlays(), 0);
        }
    }

    // Receive function test
    function test_ReceiveFunction() public {
        vm.deal(address(this), 1 ether);
        (bool success, ) = address(fap).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(fap).balance, 1 ether);
    }

    function test_Fee_WhenGameWon() public {
        // Start game with initial balance
        vm.deal(address(this), 1 ether);
        fap.startGame{value: 1 ether}();

        // First play
        address player1 = address(0x1);
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        fap.play{value: 1 ether}();

        // Record initial balances
        uint256 initialBalance1 = player1.balance;
        address player2 = address(0x2);
        vm.deal(player2, 1 ether);
        uint256 initialBalance2 = player2.balance;
        uint256 initialOwnerBalance = fap.owner().balance;

        // Wait for more than the wait time
        uint256 waitTime = fap.calculateWaitTime(1 ether);
        vm.warp(block.timestamp + waitTime + 1);

        // Second play should trigger win for first player
        vm.prank(player2);
        fap.play{value: 1 ether}();

        // Calculate expected amounts
        uint256 totalPrize = 2 ether; // Initial 1 ETH + first play 1 ETH
        uint256 expectedFee = (totalPrize * fap.FEE_PERCENTAGE()) / 100; // 1% of 2 ETH
        uint256 expectedPrize = totalPrize - expectedFee;

        // Check balances
        assertEq(
            player1.balance,
            initialBalance1 + expectedPrize,
            "Winner should receive prize minus fee"
        );
        assertEq(
            player2.balance,
            initialBalance2,
            "Player2 should be refunded"
        );
        assertEq(
            fap.owner().balance,
            initialOwnerBalance + expectedFee,
            "Owner should receive fee"
        );
    }

    function test_Fee_MultipleGames() public {
        uint256 expectedTotalFees = 0;
        feeCollected = 0; // Reset fee counter

        // Play 3 games
        for (uint256 i = 0; i < 3; i++) {
            // Start game
            vm.deal(address(this), 1 ether);
            fap.startGame{value: 1 ether}();

            // First play
            address player1 = address(uint160(i + 1));
            vm.deal(player1, 2 ether);
            vm.prank(player1);
            fap.play{value: 2 ether}();

            // Calculate fee for this game
            uint256 gamePrize = 3 ether; // 1 ETH initial + 2 ETH play
            uint256 gameFee = (gamePrize * fap.FEE_PERCENTAGE()) / 100;
            expectedTotalFees += gameFee;

            // Wait and trigger win
            uint256 waitTime = fap.calculateWaitTime(2 ether);
            vm.warp(block.timestamp + waitTime + 1);

            // Second play triggers win
            address player2 = address(uint160(i + 100));
            vm.deal(player2, 1 ether);
            vm.prank(player2);
            fap.play{value: 1 ether}();

            // Reset timestamp for next game
            vm.warp(block.timestamp + 1);
        }

        // Verify total fees collected
        assertEq(
            feeCollected,
            expectedTotalFees,
            "Owner should receive fees from all games"
        );
    }

    // Track fees in receive function
    uint256 public feeCollected;
    receive() external payable {
        feeCollected += msg.value;
    }
}
