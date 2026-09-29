// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MockVToken.sol";
import "../src/PredictionPool.sol";

contract Deploy {
    function run(address vtoken, address treasury, uint256 duration, uint256 cap)
        external
        returns (PredictionPool pool)
    {
        pool = new PredictionPool(vtoken, treasury, duration, cap);
    }
}
