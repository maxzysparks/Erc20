// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ProductionERC20Token is 
    Initializable, 
    ERC20Upgradeable, 
    PausableUpgradeable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable 
{
    using Address for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    uint256 private immutable _maxSupply;
    uint256 private constant _lockTime = 1 days;
    uint256 private constant MAX_BATCH_SIZE = 100;
    
    mapping(address => bool) private _blacklisted;
    mapping(address => bool) private _whitelisted;
    mapping(address => uint256) private _lockTimestamps;
    mapping(address => uint256) private _lockedAmounts;
    mapping(address => uint256) private _lastTransferTimestamp;
    mapping(address => uint256) private _transfersInTimeWindow;
    
    // Events
    event TokensLocked(address indexed holder, uint256 amount, uint256 lockDuration);
    event TokensUnlocked(address indexed holder, uint256 amount);
    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event EmergencyTokenRecovery(address token, address to, uint256 amount);
    event RateExceeded(address indexed account, uint256 rate);

    // Custom errors
    error InvalidAddress();
    error InsufficientBalance();
    error AccountBlacklisted(address account);
    error AccountNotWhitelisted(address account);
    error RateLimitExceeded();
    error BatchSizeTooLarge();
    error TokensLocked();
    error NoLockedTokens();
    error MaxSupplyExceeded();
    error ZeroAmount();
    error InvalidArrayLength();

    
    constructor(uint256 maxSupply_) {
        _maxSupply = maxSupply_;
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address admin
    ) initializer public {
        __ERC20_init(name, symbol);
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(initialSupply <= _maxSupply, "Initial supply exceeds max supply");
        require(admin != address(0), "Invalid admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        _mint(admin, initialSupply);
    }

    // Modifiers
    modifier notBlacklisted(address account) {
        if (_blacklisted[account]) revert AccountBlacklisted(account);
        _;
    }

    modifier onlyWhitelisted(address account) {
        if (!_whitelisted[account] && !hasRole(DEFAULT_ADMIN_ROLE, account)) {
            revert AccountNotWhitelisted(account);
        }
        _;
    }

    modifier checkRateLimit(address account) {
        if (_lastTransferTimestamp[account] + _lockTime < block.timestamp) {
            _transfersInTimeWindow[account] = 0;
        }
        if (_transfersInTimeWindow[account] >= 1000) { // 1000 transfers per day limit
            revert RateLimitExceeded();
        }
        _;
        _transfersInTimeWindow[account]++;
        _lastTransferTimestamp[account] = block.timestamp;
    }

    function lockTokens(uint256 amount, uint256 lockDuration) 
        external 
        whenNotPaused 
        nonReentrant 
        notBlacklisted(msg.sender)
        returns (bool) 
    {
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf(msg.sender)) revert InsufficientBalance();
        if (_lockTimestamps[msg.sender] != 0) revert TokensLocked();

        _transfer(msg.sender, address(this), amount);
        _lockTimestamps[msg.sender] = block.timestamp + lockDuration;
        _lockedAmounts[msg.sender] = amount;

        emit TokensLocked(msg.sender, amount, lockDuration);
        return true;
    }

    function unlockTokens() 
        external 
        whenNotPaused 
        nonReentrant 
        notBlacklisted(msg.sender)
        returns (bool) 
    {
        if (_lockTimestamps[msg.sender] == 0) revert NoLockedTokens();
        if (block.timestamp < _lockTimestamps[msg.sender]) revert TokensLocked();

        uint256 amount = _lockedAmounts[msg.sender];
        if (amount == 0) revert ZeroAmount();

        _lockedAmounts[msg.sender] = 0;
        _lockTimestamps[msg.sender] = 0;
        _transfer(address(this), msg.sender, amount);

        emit TokensUnlocked(msg.sender, amount);
        return true;
    }

    function batchTransfer(
        address[] calldata recipients, 
        uint256[] calldata amounts
    )
        external
        whenNotPaused
        nonReentrant
        notBlacklisted(msg.sender)
        checkRateLimit(msg.sender)
        returns (bool)
    {
        if (recipients.length != amounts.length) revert InvalidArrayLength();
        if (recipients.length > MAX_BATCH_SIZE) revert BatchSizeTooLarge();
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) revert ZeroAmount();
            if (recipients[i] == address(0)) revert InvalidAddress();
            totalAmount += amounts[i];
        }
        
        if (totalAmount > balanceOf(msg.sender)) revert InsufficientBalance();

        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        checkRateLimit(msg.sender)
        returns (bool)
    {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        checkRateLimit(from)
        returns (bool)
    {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        return super.transferFrom(from, to, amount);
    }

    function mint(address to, uint256 amount)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        if (totalSupply() + amount > _maxSupply) revert MaxSupplyExceeded();
        _mint(to, amount);
    }

    function burn(uint256 amount) 
        public 
        virtual 
        whenNotPaused 
        notBlacklisted(msg.sender) 
    {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
    }

    // Admin functions
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function addToBlacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklisted[account] = true;
        emit AddedToBlacklist(account);
    }

    function removeFromBlacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklisted[account] = false;
        emit RemovedFromBlacklist(account);
    }

    function addToWhitelist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelisted[account] = true;
        emit AddedToWhitelist(account);
    }

    function removeFromWhitelist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _whitelisted[account] = false;
        emit RemovedFromWhitelist(account);
    }

    function recoverTokens(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress == address(this)) revert();
        IERC20Upgradeable(tokenAddress).transfer(to, amount);
        emit EmergencyTokenRecovery(tokenAddress, to, amount);
    }

    // View functions
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisted[account];
    }

    function getLockedAmount(address account) public view returns (uint256) {
        return _lockedAmounts[account];
    }

    function getLockTimestamp(address account) public view returns (uint256) {
        return _lockTimestamps[account];
    }

    function getTransfersInTimeWindow(address account) public view returns (uint256) {
        return _transfersInTimeWindow[account];
    }

    // Required overrides
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}