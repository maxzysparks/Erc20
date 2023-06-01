contract ERC20TokenTest {
    ERC20Token token;
    
    constructor() {
        token = new ERC20Token("Test Token", "TTK");
    }
    
    function testToken() external {
        // Initial state
        require(token.totalSupply() == 1000 * 10 ** 18, "Incorrect initial supply");
        require(token.balanceOf(address(this)) == 1000 * 10 ** 18, "Incorrect initial balance");
        
        // Transfer tokens
        address recipient = address(0x123456789);
        uint256 transferAmount = 100 * 10 ** 18;
        require(token.transfer(recipient, transferAmount), "Transfer failed");
        require(token.balanceOf(address(this)) == 900 * 10 ** 18, "Incorrect balance after transfer");
        require(token.balanceOf(recipient) == transferAmount, "Incorrect recipient balance after transfer");
        
        // Approve and transferFrom
        address spender = address(0x987654321);
        uint256 approvalAmount = 50 * 10 ** 18;
        require(token.approve(spender, approvalAmount), "Approval failed");
        require(token.allowance(address(this), spender) == approvalAmount, "Incorrect allowance");
        require(token.transferFrom(address(this), recipient, approvalAmount), "TransferFrom failed");
        require(token.balanceOf(address(this)) == 850 * 10 ** 18, "Incorrect balance after transferFrom");
        require(token.balanceOf(recipient) == transferAmount + approvalAmount, "Incorrect recipient balance after transferFrom");
        
        // Burn tokens
        uint256 burnAmount = 100 * 10 ** 18;
        require(token.burn(burnAmount), "Burn failed");
        require(token.balanceOf(address(this)) == 750 * 10 ** 18, "Incorrect balance after burn");
        require(token.totalSupply() == 900 * 10 ** 18, "Incorrect total supply after burn");
        
        // Mint tokens
        address minter = address(0x246813579);
        uint256 mintAmount = 200 * 10 ** 18;
        require(token.mint(minter, mintAmount), "Mint failed");
        require(token.balanceOf(minter) == mintAmount, "Incorrect minter balance after mint");
        require(token.totalSupply() == 1100 * 10 ** 18, "Incorrect total supply after mint");
    }
}
