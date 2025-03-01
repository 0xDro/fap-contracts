// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Fap} from "../src/fap.sol";

contract Play is Script {
    function run() external {
        // Get the deployed contract address
        address payable fapAddress = payable(
            0x48B5e936600B3F6894aDaD77b106872F3035bCb6
        );
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Create contract instance
        Fap fap = Fap(fapAddress);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Play with minimum deposit (0.0001 ETH)
        fap.play{value: 0.0001 ether}();

        vm.stopBroadcast();

        // Log the transaction
        console.log("Played on Fap contract:", address(fap));
        console.log("Deposit amount:", 0.0001 ether, "wei");
        console.log(
            "Wait time:",
            fap.calculateWaitTime(0.0001 ether),
            "seconds"
        );
    }
}
