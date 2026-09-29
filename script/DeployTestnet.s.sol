// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MockVToken.sol";
import "../src/PredictionPool.sol";

// Cheatcode interface (no forge-std dependency needed).
interface VmScript {
    function startBroadcast() external;
    function stopBroadcast() external;
}
VmScript constant VM = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

// One-shot deploy + seed for testnet demo:
//   forge script script/DeployTestnet.s.sol --rpc-url $RPC_URL \
//     --private-key $PK --broadcast
//
// Deploys MockVToken + PredictionPool ("Will DOT exceed $10?", 7-day round,
// 10k cap), funds the deployer with 500 mock vDOT for demo deposits.
// All addresses are printed by forge broadcast logs.
contract DeployTestnet {
    function run() external returns (MockVToken mv, PredictionPool pool) {
        VM.startBroadcast();
        mv = new MockVToken();
        pool = new PredictionPool(
            address(mv),
            msg.sender, // treasury = deployer (testnet only)
            7 days,
            10_000 ether,
            "Will DOT exceed $10 at round end?",
            10e8 // $10 in CoinGecko 8dp scale
        );
        mv.mint(msg.sender, 500 ether);
        VM.stopBroadcast();
    }
}
