// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Mock vToken for testnet MVP: behaves like a yield-bearing LST.
// `accrueYield` simulates staking rewards landing in a holder (the pool).
contract MockVToken {
    string public constant name = "Mock vDOT";
    string public constant symbol = "mvDOT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amt) external {
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    // Simulate staking yield: mints fresh tokens to the pool address.
    function accrueYield(address pool, uint256 amt) external {
        totalSupply += amt;
        balanceOf[pool] += amt;
        emit Transfer(address(0), pool, amt);
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "insufficient");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        emit Approval(msg.sender, sp, amt);
        return true;
    }

    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        require(a >= amt, "allowance");
        require(balanceOf[f] >= amt, "insufficient");
        if (a != type(uint256).max) allowance[f][msg.sender] = a - amt;
        balanceOf[f] -= amt;
        balanceOf[t] += amt;
        emit Transfer(f, t, amt);
        return true;
    }
}
