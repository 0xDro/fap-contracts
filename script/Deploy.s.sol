// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Fap} from "../src/fap.sol";

contract DeployFap is Script {
    function run() external {
        // Retrieve deployer private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        Fap fap = new Fap();

        // Optional: Start first game with initial pool
        // fap.startGame{value: 1 ether}();

        vm.stopBroadcast();

        // Log the contract address
        console.log("Fap deployed to:", address(fap));
    }
}
