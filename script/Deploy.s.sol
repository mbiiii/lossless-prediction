// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/PredictionPool.sol";

// Deploy to Moonbase Alpha:
//   forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PK --broadcast
contract Deploy {
    function run(
        address vtoken,
        address treasury,
        uint256 duration,
        uint256 cap,
        string memory question,
        uint256 strikePrice
    ) external returns (PredictionPool pool) {
        pool = new PredictionPool(vtoken, treasury, duration, cap, question, strikePrice, 12 hours);
    }
}
