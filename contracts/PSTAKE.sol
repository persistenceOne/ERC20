// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IPSTAKE.sol";

contract PSTAKE is
	IPSTAKE,
	ERC20Upgradeable,
	PausableUpgradeable,
	AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
	// constants defining access control ROLES
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	// variables capturing data of other contracts in the product
	address public _stakeLPCoreContract;

	// variable pertaining to contract upgrades versioning
	uint256 private _version;

     // ERC20 basic token contract being held
    IERC20Upgradeable _token;
    
    // Struct to hold vesting grant
    struct Grant {
        uint256 startTime;
        uint256 amount;
        uint256 vestingCliff;
        address benificiary;
        bool isActive;
    }

    // contract state variables
    mapping (address => Grant) public vestingGrants;
    uint256 public totalVestedHistory;
    uint256 public totalVestingAmount;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // contract events
    event GrantAdded(address indexed benificiary, uint256 grantNumber, uint256 timestamp);
    event GrantClaimed(address indexed benificiary, uint256 indexed amount, uint256 timestamp);
    event GrantRevoked(address indexed benificiary, address indexed vestingProvider, uint256 timestamp);

	/**
	 * @dev Constructor for initializing the UToken contract.
	 * @param pauserAddress - address of the pauser admin.
	 */
	function initialize(address pauserAddress) public virtual initializer {
		__ERC20_init("pSTAKE Token", "PSTAKE");
		__AccessControl_init();
		__Pausable_init();
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		_setupRole(PAUSER_ROLE, pauserAddress);
		// PSTAKE IS A SIMPLE ERC20 TOKEN HENCE 18 DECIMAL PLACES
		_setupDecimals(18);
		// pre-allocate some tokens to an admin address which will air drop PSTAKE tokens
		// to each of holder contracts. This is only for testnet purpose. in Mainnet, we
		// will use a vesting contract to allocate tokens to admin in a certain schedule
		_mint(_msgSender(), 5000000000000000000000000);
	}

	/**
	 * @dev Mint new PSTAKE for the provided 'address' and 'amount'
	 *
	 *
	 * Emits a {MintTokens} event with 'to' set to address and 'tokens' set to amount of tokens.
	 *
	 * Requirements:
	 *
	 * - `amount` cannot be less than zero.
	 *
	 */
	function mint(address to, uint256 tokens) public virtual override returns (bool success) {
        require(_msgSender() == _stakeLPCoreContract, "PS1");  // minted by STokens contract

        _mint(to, tokens);
        return true;
    }

	/*
	 * @dev Burn utokens for the provided 'address' and 'amount'
	 * @param from: account address, tokens: number of tokens
	 *
	 * Emits a {BurnTokens} event with 'from' set to address and 'tokens' set to amount of tokens.
	 *
	 * Requirements:
	 *
	 * - `amount` cannot be less than zero.
	 *
	 */
	function burn(address from, uint256 tokens) public virtual override returns (bool success) {
        require((tx.origin == from && _msgSender()==_liquidStakingContract) ||  // staking operation
        (tx.origin == from && _msgSender() == _wrapperContract), "UT2"); // unwrap operation
        _burn(from, tokens);
        return true;
    }

	/*
	 * @dev Set 'contract address', for liquid staking smart contract
	 * @param liquidStakingContract: liquidStaking contract address
	 *
	 * Emits a {SetLiquidStakingContract} event with '_contract' set to the liquidStaking contract address.
	 *
	 */
	function setStakeLPCoreContract(address stakeLPCoreContract)
		public
		virtual
		override
	{
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS2");
		_stakeLPCoreContract = stakeLPCoreContract;
		emit SetStakeLPCoreContract(stakeLPCoreContract);
	}

	/**
	 * @dev Triggers stopped state.
	 *
	 * Requirements:
	 *
	 * - The contract must not be paused.
	 */
	function pause() public virtual returns (bool success) {
		require(hasRole(PAUSER_ROLE, _msgSender()), "PS3");
		_pause();
		return true;
	}

	/**
	 * @dev Returns to normal state.
	 *
	 * Requirements:
	 *
	 * - The contract must be paused.
	 */
	function unpause() public virtual returns (bool success) {
		require(hasRole(PAUSER_ROLE, _msgSender()), "PS4");
		_unpause();
		return true;
	}

	/**
	 * @dev Hook that is called before any transfer of tokens. This includes
	 * minting and burning.
	 *
	 * Calling conditions:
	 *
	 * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
	 * will be to transferred to `to`.
	 * - when `from` is zero, `amount` tokens will be minted for `to`.
	 * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
	 * - `from` and `to` are never both zero.
	 *
	 */
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal virtual override {
		require(!paused(), "PS5");
		super._beforeTokenTransfer(from, to, amount);
	}

    // vesting logic

     /**
     * @return the token being held.
     */
    function token() public view returns (IERC20Upgradeable) {
        return _token;
    }

    /**
     * @dev get the details of the vesting grant for a user
     */
     function getGrant(address beneficiary_) public view returns (
        uint256 startTime,
        uint256 amount,
        uint256 vestingCliff,    
        address benificiary, 
        bool isActive)
    {
        Grant memory _grant = vestingGrants[beneficiary_];
        startTime = _grant.startTime;
        amount = _grant.amount;
        vestingCliff = _grant.vestingCliff;
        benificiary = _grant.benificiary;
        isActive = _grant.isActive;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function claimGrant(address beneficiary_) external nonReentrant whenNotPaused {
        require(beneficiary_ == _msgSender(), "VestingTimelock: Unauthorized User");

        Grant memory _grant = vestingGrants[beneficiary_];

         // check whether the grant is active
        require(_grant.isActive, "VestingTimelock: Grant is not active");

        // check whether the amount is not zero
        uint256 _amount = _grant.amount;
        require(_amount > 0, "VestingTimelock: No tokens to claim");

        // check whether the vesting cliff time has elapsed
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= _grant.vestingCliff, "VestingTimelock: Grant still vesting");

        // reset all the grant detail variables to zero
        delete vestingGrants[beneficiary_];
        // update totalVestingAmount and transfer ERC20 tokens
        totalVestingAmount = totalVestingAmount.sub(_amount);
        emit GrantClaimed(beneficiary_, _amount, block.timestamp);

        token().safeTransfer(beneficiary_, _amount);
    }

    /**
     * @notice Transfers tokens held by beneficiary to timelock.
     */
    function _addGrant(
        uint256 startTime_,
        uint256 amount_,
        uint256 vestingCliff_,    
        address benificiary_
    ) 
        internal
    {
        require(amount_ > 0, "VestingTimelock: No tokens to add");
        require(startTime_ <= vestingCliff_, "VestingTimelock: cliff before start time");

        // allow adding grants whose vesting schedule is already realized, so commented below line
        // require(vestingCliff_ >= block.timestamp, "VestingTimelock: vesting cliff is in the past");

        Grant memory _grant = vestingGrants[benificiary_];
        require(!_grant.isActive, "VestingTimelock: grant already active");

        Grant memory grant = Grant({
            startTime: startTime_,
            amount: amount_,
            vestingCliff: vestingCliff_,
            benificiary: benificiary_,
            isActive: true
        });

        totalVestedHistory = totalVestedHistory.add(1);
        totalVestingAmount = totalVestingAmount.add(amount_);
        vestingGrants[benificiary_] = grant;
    }

    /**
     * @notice Transfers tokens held by beneficiary to timelock.
     */
    function addGrant(
        uint256 startTime_,
        uint256 amount_,
        uint256 vestingCliff_,    
        address benificiary_
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VestingTimelock: Unauthorized User");
        _addGrant(
            startTime_,
            amount_,
            vestingCliff_,    
            benificiary_
        );
        emit GrantAdded(benificiary_, totalVestedHistory, block.timestamp);

    }

    /**
     * @notice Transfers tokens held by beneficiary to timelock.
     */
    function addGrants(
        uint256[] calldata startTimes_,
        uint256[] calldata amounts_,
        uint256[] calldata vestingCliffs_,    
        address[] calldata benificiaries_
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VestingTimelock: Unauthorized User");
        require(benificiaries_.length > 0 && benificiaries_.length == amounts_.length && startTimes_.length == amounts_.length && startTimes_.length == vestingCliffs_.length, "VestingTimelock: invalid array size");

        // allocate the grants to the respective benificiaries
        uint256 i;
        for (i=0; i<benificiaries_.length; i++) {
            _addGrant(
                startTimes_[i],
                amounts_[i],
                vestingCliffs_[i],    
                benificiaries_[i]
            );
        }

        // emit the data of last grant that was added
        emit GrantAdded(benificiaries_[i.sub(1)], totalVestedHistory, block.timestamp);
    }

     /**
     * @notice revokeGrant tokens held by timelock to beneficiary.
     */
     function _revokeGrant(address beneficiary_, address vestingProvider_) internal
    {
        Grant memory _grant = vestingGrants[beneficiary_];

        // check whether the grant is active
        require(_grant.isActive, "VestingTimelock: Grant is not active");

        // check whether the amount is a non zero value
        uint256 _amount = _grant.amount;
        require(_amount > 0, "VestingTimelock: No tokens to revoke");

        // reset all the grant detail variables to zero
        delete vestingGrants[beneficiary_];
        totalVestingAmount = totalVestingAmount.sub(_amount);
        totalVestedHistory = totalVestedHistory.sub(1);

        // transfer the erc20 token amount back to the vesting provider 
        // needs to be done as there is no other means to transfer ERC20 tokens without keys. 
        // except by defining custom grant for a self controlled wallet address then claiming the grant. 
        token().safeTransfer(vestingProvider_, _amount);
    }

    /**
     * @notice revokeGrant tokens held by timelock to beneficiary.
     */
    function revokeGrant(address beneficiary_, address vestingProvider_) external {
        // revoke currently doesnt return the ERC20 tokens sent to this contract
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VestingTimelock: Unauthorized User");

        _revokeGrant(beneficiary_, vestingProvider_);
        emit GrantRevoked(beneficiary_, vestingProvider_, block.timestamp);
    }

    /**
     * @notice revoke vesting grants of multiple benificiaries.
     */
    function revokeGrants(
        address[] calldata benificiaries_,
        address vestingProvider_
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VestingTimelock: Unauthorized User");
        require(benificiaries_.length > 0 , "VestingTimelock: invalid array size");

        // allocate the grants to the respective addresses
        uint256 i;
        for (i=0; i<benificiaries_.length; i++) {
            _revokeGrant(
                benificiaries_[i],
                vestingProvider_
            );
        }

        // emit the data of last grant that was revoked
        emit GrantRevoked(benificiaries_[i.sub(1)], vestingProvider_, block.timestamp);
    }

    /**
     * @notice Returns the quantity of unclaimed PSTAKE allocated privately to `holder`.
     * @param holder The holder of the unclaimed PSTAKE allocated privately.
     * @return The quantity of unclaimed PSTAKE.
     */
    function getUnclaimedPrivatePSTAKE(address holder) public view returns (uint256) {
        return privatePSTAKEAllocations[holder].sub(_privatePSTAKEClaimed[holder]);
    }

    /**
     * @notice Internal function to claim `amount` unclaimed PSTAKE allocated privately to `holder` (without validating `amount`).
     * @param holder The holder of the unclaimed PSTAKE allocated privately.
     * @param amount The amount of PSTAKE to claim.
     */
    function _claimPrivatePSTAKE(address holder, uint256 amount) internal {
        uint256 burnPSTAKE = amount.mul(getPrivatePSTAKEClaimFee(block.timestamp)).div(1e18);
        uint256 transferPSTAKE = amount.sub(burnPSTAKE);
        _privatePSTAKEClaimed[holder] = _privatePSTAKEClaimed[holder].add(amount);
        require(rariGovernanceToken.transfer(holder, transferPSTAKE), "Failed to transfer PSTAKE from vesting reserve.");
        rariGovernanceToken.burn(burnPSTAKE);
        emit PrivateClaim(holder, amount, transferPSTAKE, burnPSTAKE);
    }

    /**
     * @notice Claims `amount` unclaimed PSTAKE allocated privately to `msg.sender`.
     * @param amount The amount of PSTAKE to claim.
     */
    function claimPrivatePSTAKE(uint256 amount) external {
        uint256 unclaimedPSTAKE = getUnclaimedPrivatePSTAKE(msg.sender);
        require(amount <= unclaimedPSTAKE, "This amount is greater than the unclaimed PSTAKE allocated privately.");
        _claimPrivatePSTAKE(msg.sender, amount);
    }

    /**
     * @notice Claims all unclaimed PSTAKE allocated privately to `msg.sender`.
     */
    function claimAllPrivatePSTAKE() external {
        uint256 unclaimedPSTAKE = getUnclaimedPrivatePSTAKE(msg.sender);
        require(unclaimedPSTAKE > 0, "Unclaimed PSTAKE allocated privately not greater than 0.");
        _claimPrivatePSTAKE(msg.sender, unclaimedPSTAKE);
    }

}
