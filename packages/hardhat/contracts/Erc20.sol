// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

contract ERC20Token {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint256 private maxSupply = 1000000 * 10 ** 18;
    uint8 public decimals = 18;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => uint256) private lockTimestamps;

    constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
        totalSupply = 1000 * 10 ** 18; // Initial supply of 1000 tokens
        balances[msg.sender] = totalSupply;
    }

    function setDecimals(uint8 newDecimals) public {
        require(
            msg.sender == address(this),
            "Only contract creator can set decimals"
        );
        decimals = newDecimals;
    }

    function changeSymbol(string memory newSymbol) public {
        require(
            msg.sender == address(this),
            "Only contract creator can change symbol"
        );
        symbol = newSymbol;
    }

    function changeName(string memory newName) public {
        require(
            msg.sender == address(this),
            "Only contract creator can change name"
        );
        name = newName;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(amount <= balances[msg.sender], "Insufficient balance");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function lockTokens(
        uint256 amount,
        uint256 lockDuration
    ) public returns (bool) {
        require(amount <= balances[msg.sender], "Insufficient balance");

        balances[msg.sender] -= amount;
        balances[address(this)] += amount;

        lockTimestamps[msg.sender] = block.timestamp + lockDuration;

        emit LockTokens(msg.sender, amount, lockDuration);

        return true;
    }

    function batchTransfer(
        address[] memory recipients,
        uint256[] memory amounts
    ) public returns (bool) {
        require(recipients.length == amounts.length, "Array length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalAmount += amounts[i];
            _transfer(msg.sender, recipients[i], amounts[i]);
        }

        require(totalAmount <= balances[msg.sender], "Insufficient balance");

        return true;
    }

    function unlockTokens() public returns (bool) {
        require(lockTimestamps[msg.sender] > 0, "No locked tokens found");
        require(
            block.timestamp >= lockTimestamps[msg.sender],
            "Tokens are still locked"
        );

        uint256 amount = balances[address(this)];

        balances[msg.sender] += amount;
        balances[address(this)] = 0;
        lockTimestamps[msg.sender] = 0;

        emit UnlockTokens(msg.sender, amount);

        return true;
    }

    event LockTokens(
        address indexed holder,
        uint256 amount,
        uint256 lockDuration
    );
    event UnlockTokens(address indexed holder, uint256 amount);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(amount <= balances[sender], "Insufficient balance");
        require(
            amount <= allowances[sender][msg.sender],
            "Insufficient allowance"
        );
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowances[sender][msg.sender] - amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function burn(uint256 amount) public returns (bool) {
        require(amount <= balances[msg.sender], "Insufficient balance");
        require(amount <= totalSupply, "Cannot burn more than total supply");
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        return true;
    }

    function mint(address account, uint256 amount) public returns (bool) {
        require(
            msg.sender == address(this),
            "Only contract creator can mint tokens"
        );
        require(totalSupply + amount <= maxSupply, "Exceeds maximum supply");
        balances[account] += amount;
        totalSupply += amount;
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        balances[sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
