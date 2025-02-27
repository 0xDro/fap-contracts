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
}
