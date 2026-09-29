// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ReceiptToken.sol";

interface IERC20 {
    function transfer(address to, uint256 amt) external returns (bool);
    function transferFrom(address f, address t, uint256 amt) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
}

// Lossless prediction market over a yield-bearing vToken.
// Users deposit vTokens picking YES/NO. Principal is never at risk:
// only the yield accrued during the round is paid to the winning side.
// Losers withdraw their full principal. 5% fee on yield goes to treasury.
contract PredictionPool {
    IERC20 public immutable vtoken;
    ReceiptToken public immutable yesToken;
    ReceiptToken public immutable noToken;

    address public owner;
    address public treasury;
    uint256 public feeBps = 500; // 5% of yield
    uint256 public immutable endTime;
    uint256 public immutable maxDeposit; // per-round cap (abuse guard, MVP)
    string public question; // e.g. "Will DOT exceed $10 at round end?"
    uint256 public strikePrice; // USD with 8 decimals (CoinGecko scale)
    uint256 public resolvedPrice; // price posted at resolve, 8 decimals

    bool public resolved;
    bool public outcomeYes;
    uint256 public disputeEnd;
    bool public finalized;

    uint256 public snapshotYield; // yield net of fee, fixed at finalize
    uint256 public totalPrincipalYes;
    uint256 public totalPrincipalNo;
    uint256 public totalSharesYes;
    uint256 public totalSharesNo;
    uint256 public totalDeposited;

    mapping(address => uint256) public principalYes;
    mapping(address => uint256) public principalNo;
    mapping(address => bool) public claimed;

    uint256 public immutable disputeWindow; // e.g. 12h pilot, short for demo
    uint256 public constant SWEEP_DELAY = 30 days;
    uint256 public finalizedAt;

    event Deposit(address indexed user, bool indexed predictYes, uint256 amount);
    event Resolved(bool outcomeYes);
    event Disputed(bool newOutcome);
    event Finalized(uint256 grossYield, uint256 fee, uint256 netYield);
    event Claim(address indexed user, uint256 principal, uint256 winnings);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(
        address _vtoken,
        address _treasury,
        uint256 _duration,
        uint256 _maxDeposit,
        string memory _question,
        uint256 _strikePrice,
        uint256 _disputeWindow
    ) {
        require(_vtoken != address(0) && _treasury != address(0), "zero addr");
        require(_duration > 0 && _maxDeposit > 0 && _strikePrice > 0, "bad params");
        require(_disputeWindow > 0, "bad dispute window");
        vtoken = IERC20(_vtoken);
        treasury = _treasury;
        endTime = block.timestamp + _duration;
        maxDeposit = _maxDeposit;
        question = _question;
        strikePrice = _strikePrice;
        disputeWindow = _disputeWindow;
        yesToken = new ReceiptToken("Pool YES", "pYES", address(this));
        noToken = new ReceiptToken("Pool NO", "pNO", address(this));
        owner = msg.sender;
    }

    // Deposit vTokens before endTime. Shares are 1:1 with amount (MVP:
    // deposits allowed through the whole round, so late entries get the
    // same rate; cap + lock are the abuse guards for the pilot).
    function deposit(uint256 amount, bool predictYes) external {
        require(block.timestamp < endTime, "round closed");
        require(amount > 0, "zero");
        require(totalDeposited + amount <= maxDeposit, "round cap");
        require(vtoken.transferFrom(msg.sender, address(this), amount), "transfer fail");

        totalDeposited += amount;
        if (predictYes) {
            principalYes[msg.sender] += amount;
            totalPrincipalYes += amount;
            totalSharesYes += amount;
            yesToken.mint(msg.sender, amount);
        } else {
            principalNo[msg.sender] += amount;
            totalPrincipalNo += amount;
            totalSharesNo += amount;
            noToken.mint(msg.sender, amount);
        }
        emit Deposit(msg.sender, predictYes, amount);
    }

    // MVP resolver: owner posts the outcome after round end.
    // Upgrade path (M2): on-chain oracle (DIA/Pyth on Moonbeam).
    function resolve(bool _outcomeYes) external onlyOwner {
        require(block.timestamp >= endTime, "round live");
        require(!resolved, "already resolved");
        resolved = true;
        outcomeYes = _outcomeYes;
        disputeEnd = block.timestamp + disputeWindow;
        emit Resolved(_outcomeYes);
    }

    // Resolver path (M2 bot): owner posts the observed price, outcome is
    // derived mechanically: price >= strike -> YES wins.
    function resolveWithPrice(uint256 price) external onlyOwner {
        require(block.timestamp >= endTime, "round live");
        require(!resolved, "already resolved");
        require(price > 0, "bad price");
        resolved = true;
        resolvedPrice = price;
        outcomeYes = price >= strikePrice;
        disputeEnd = block.timestamp + disputeWindow;
        emit Resolved(outcomeYes);
    }

    // Owner can flip the outcome inside the dispute window.
    function dispute(bool _newOutcome) external onlyOwner {
        require(resolved && !finalized, "not disputable");
        require(block.timestamp < disputeEnd, "window over");
        outcomeYes = _newOutcome;
        emit Disputed(_newOutcome);
    }

    // Lock the numbers: yield = balance - principals, fee to treasury.
    function finalize() external {
        require(resolved, "not resolved");
        require(!finalized, "already");
        require(block.timestamp >= disputeEnd, "in dispute");
        finalized = true;
        finalizedAt = block.timestamp;

        uint256 bal = vtoken.balanceOf(address(this));
        uint256 principals = totalPrincipalYes + totalPrincipalNo;
        uint256 gross = bal > principals ? bal - principals : 0;
        uint256 fee = (gross * feeBps) / 10000;
        snapshotYield = gross - fee;
        if (fee > 0) require(vtoken.transfer(treasury, fee), "fee fail");
        emit Finalized(gross, fee, snapshotYield);
    }

    // One claim per user: burns both receipts, returns principal of the
    // side(s) held plus pro-rata yield if on the winning side.
    function claim() external {
        require(finalized, "not finalized");
        require(!claimed[msg.sender], "claimed");
        claimed[msg.sender] = true;

        uint256 yBal = yesToken.balanceOf(msg.sender);
        uint256 nBal = noToken.balanceOf(msg.sender);
        require(yBal > 0 || nBal > 0, "no position");

        if (yBal > 0) yesToken.burnFrom(msg.sender, yBal);
        if (nBal > 0) noToken.burnFrom(msg.sender, nBal);

        uint256 payout = principalYes[msg.sender] + principalNo[msg.sender];
        uint256 winnings = 0;

        if (outcomeYes && yBal > 0 && totalSharesYes > 0) {
            winnings = (snapshotYield * yBal) / totalSharesYes;
        } else if (!outcomeYes && nBal > 0 && totalSharesNo > 0) {
            winnings = (snapshotYield * nBal) / totalSharesNo;
        }

        uint256 total = payout + winnings;
        require(total > 0, "nothing");
        require(vtoken.transfer(msg.sender, total), "payout fail");
        emit Claim(msg.sender, payout, winnings);
    }

    // After SWEEP_DELAY, owner can rescue dust / unclaimed remainder
    // (e.g. yield when nobody bet the winning side) to treasury.
    function sweep() external onlyOwner {
        require(finalized, "not finalized");
        require(block.timestamp >= finalizedAt + SWEEP_DELAY, "too early");
        uint256 bal = vtoken.balanceOf(address(this));
        require(bal > 0, "empty");
        require(vtoken.transfer(treasury, bal), "sweep fail");
    }

    function transferOwnership(address n) external onlyOwner {
        require(n != address(0), "zero");
        owner = n;
    }
}
