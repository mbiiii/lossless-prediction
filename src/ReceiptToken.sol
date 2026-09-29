// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal ERC20 receipt token. Only the pool (minter) can mint/burn.
contract ReceiptToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public immutable minter;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory n, string memory s, address m) {
        name = n;
        symbol = s;
        minter = m;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "not minter");
        _;
    }

    function mint(address to, uint256 amt) external onlyMinter {
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burnFrom(address from, uint256 amt) external onlyMinter {
        require(balanceOf[from] >= amt, "insufficient");
        balanceOf[from] -= amt;
        totalSupply -= amt;
        emit Transfer(from, address(0), amt);
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
