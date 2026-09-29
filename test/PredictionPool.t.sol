// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MockVToken.sol";
import "../src/PredictionPool.sol";

// forge cheatcodes (no forge-std dependency needed)
interface Vm {
    function warp(uint256) external;
}
Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

// Distinct actor that holds tokens and talks to the pool.
contract Player {
    function doApprove(address token, address pool, uint256 amt) external {
        MockVToken(token).approve(pool, amt);
    }
    function doDeposit(address pool, uint256 amt, bool side) external {
        PredictionPool(pool).deposit(amt, side);
    }
    function doClaim(address pool) external {
        PredictionPool(pool).claim();
    }
}

contract PredictionPoolTest {
    MockVToken v;
    PredictionPool pool;
    Player pA;
    Player pB;
    address treasury = address(0xBEEF);

    function setUp() public {
        v = new MockVToken();
        pool = new PredictionPool(address(v), treasury, 7 days, 10_000 ether, "Will DOT exceed $10 at round end?", 10e8);
        pA = new Player();
        pB = new Player();
        v.mint(address(pA), 1_000 ether);
        v.mint(address(pB), 1_000 ether);
        pA.doApprove(address(v), address(pool), type(uint256).max);
        pB.doApprove(address(v), address(pool), type(uint256).max);
    }

    function _closeResolveFinalize(bool outcome) internal {
        vm.warp(pool.endTime() + 1);
        pool.resolve(outcome);
        vm.warp(pool.disputeEnd() + 1);
        pool.finalize();
    }

    function testFullRoundYesWins() public {
        pA.doDeposit(address(pool), 100 ether, true); // alice YES
        pB.doDeposit(address(pool), 100 ether, false); // bob NO

        // staking yield lands in the pool: 8 vTokens
        v.accrueYield(address(pool), 8 ether);
        _closeResolveFinalize(true);

        // fee = 5% of 8 = 0.4 ; net 7.6 all to alice (sole YES)
        require(v.balanceOf(treasury) == 0.4 ether, "fee wrong");

        uint256 a0 = v.balanceOf(address(pA));
        uint256 b0 = v.balanceOf(address(pB));
        pA.doClaim(address(pool));
        pB.doClaim(address(pool));
        require(v.balanceOf(address(pA)) == a0 + 100 ether + 7.6 ether, "alice payout wrong");
        require(v.balanceOf(address(pB)) == b0 + 100 ether, "bob principal wrong");
    }

    function testResolveWithPrice() public {
        pA.doDeposit(address(pool), 100 ether, true);
        pB.doDeposit(address(pool), 100 ether, false);
        v.accrueYield(address(pool), 8 ether);
        vm.warp(pool.endTime() + 1);
        pool.resolveWithPrice(12e8); // $12 >= $10 strike -> YES
        require(pool.outcomeYes(), "should be YES");
        require(pool.resolvedPrice() == 12e8, "price not stored");
        vm.warp(pool.disputeEnd() + 1);
        pool.finalize();
        uint256 a0 = v.balanceOf(address(pA));
        pA.doClaim(address(pool));
        require(v.balanceOf(address(pA)) == a0 + 100 ether + 7.6 ether, "alice payout wrong");
    }

    function testLoserPrincipalSafeWhenNoWins() public {
        pA.doDeposit(address(pool), 50 ether, true);
        pB.doDeposit(address(pool), 150 ether, false);
        v.accrueYield(address(pool), 4 ether);
        _closeResolveFinalize(false);

        // net yield = 3.8, all to bob (sole NO)
        uint256 a0 = v.balanceOf(address(pA));
        uint256 b0 = v.balanceOf(address(pB));
        pA.doClaim(address(pool));
        pB.doClaim(address(pool));
        require(v.balanceOf(address(pA)) == a0 + 50 ether, "alice principal wrong");
        require(
            v.balanceOf(address(pB)) == b0 + 150 ether + 3.8 ether,
            "bob payout wrong"
        );
    }

    function testProRataSplitTwoWinners() public {
        pA.doDeposit(address(pool), 100 ether, true);
        pB.doDeposit(address(pool), 300 ether, true);
        v.accrueYield(address(pool), 10 ether);
        _closeResolveFinalize(true);

        // net = 9.5 ; alice 1/4 = 2.375, bob 3/4 = 7.125
        uint256 a0 = v.balanceOf(address(pA));
        uint256 b0 = v.balanceOf(address(pB));
        pA.doClaim(address(pool));
        pB.doClaim(address(pool));
        require(v.balanceOf(address(pA)) == a0 + 100 ether + 2.375 ether, "alice split wrong");
        require(v.balanceOf(address(pB)) == b0 + 300 ether + 7.125 ether, "bob split wrong");
    }

    function testDepositAfterEndReverts() public {
        vm.warp(pool.endTime() + 1);
        pA.doApprove(address(v), address(pool), 1 ether);
        (bool ok, ) = address(pA).call(
            abi.encodeWithSignature("doDeposit(address,uint256,bool)", address(pool), 1 ether, true)
        );
        require(!ok, "late deposit should revert");
    }

    function testResolveBeforeEndReverts() public {
        (bool ok, ) = address(pool).call(abi.encodeWithSignature("resolve(bool)", true));
        require(!ok, "early resolve should revert");
    }

    function testDoubleClaimReverts() public {
        pA.doDeposit(address(pool), 10 ether, true);
        _closeResolveFinalize(true);
        pA.doClaim(address(pool));
        (bool ok, ) = address(pA).call(
            abi.encodeWithSignature("doClaim(address)", address(pool))
        );
        require(!ok, "double claim should revert");
    }

    function testZeroYieldRoundPrincipalOnly() public {
        pA.doDeposit(address(pool), 25 ether, true);
        pB.doDeposit(address(pool), 25 ether, false);
        // no yield at all
        _closeResolveFinalize(true);
        uint256 a0 = v.balanceOf(address(pA));
        uint256 b0 = v.balanceOf(address(pB));
        pA.doClaim(address(pool));
        pB.doClaim(address(pool));
        require(v.balanceOf(address(pA)) == a0 + 25 ether, "alice principal wrong");
        require(v.balanceOf(address(pB)) == b0 + 25 ether, "bob principal wrong");
    }
}
