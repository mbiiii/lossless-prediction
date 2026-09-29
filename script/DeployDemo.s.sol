// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MockVToken.sol";
import "../src/PredictionPool.sol";

// Cheatcode interface (no forge-std dependency needed).
interface VmDemo {
    function startBroadcast() external;
    function stopBroadcast() external;
}
VmDemo constant VM2 = VmDemo(address(uint160(uint256(keccak256("hevm cheat code")))));

// Demo pool for the 3-minute video walkthrough:
// 5-minute round + 5-minute dispute window, small cap.
//   forge script script/DeployDemo.s.sol --rpc-url $RPC_URL \
//     --private-key $PK --broadcast
contract DeployDemo {
    function run() external returns (MockVToken mv, PredictionPool pool) {
        VM2.startBroadcast();
        mv = new MockVToken();
        pool = new PredictionPool(
            address(mv),
            msg.sender, // treasury = deployer (testnet only)
            5 minutes, // short round for demo
            1_000 ether, // small cap for demo
            "Demo: Will DOT exceed $10 at round end?",
            10e8, // $10 in CoinGecko 8dp scale
            5 minutes // short dispute window for demo (pilot uses 12h)
        );
        mv.mint(msg.sender, 500 ether);
        VM2.stopBroadcast();
    }
}
