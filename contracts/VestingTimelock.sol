// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 *
 * Useful for simple vesting schedules like "advisors get all of their tokens
 * after 1 year"
 */
contract VestingTimelock is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, AccessControlUpgradeable{
    
    // including libraries
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

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
   * @dev Constructor for initializing the Vesting Timelock contract.
   * @param token_ - IERC20 token address.
   * @param pauserAddress_ - address of the pauser admin.
   */
    function initialize(IERC20Upgradeable token_, address pauserAddress_) public virtual initializer {
        __Context_init_unchained();
        __ReentrancyGuard_init();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, pauserAddress_);
        _token = token_;
    }

    /**
     * @return the token being held.
     */
    function token() public view returns (IERC20Upgradeable) {
        return _token;
    }

    /**
     * @dev get the details of the vesting grant for a user
     * @param beneficiary_: beneficiary address
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
     * @param beneficiary_: beneficiary address
     */
    function claimGrant(address beneficiary_) external nonReentrant whenNotPaused {
        require(beneficiary_ == _msgSender(), "VT1");

        Grant memory _grant = vestingGrants[beneficiary_];

         // check whether the grant is active
        require(_grant.isActive, "VT2");

        // check whether the amount is not zero
        uint256 _amount = _grant.amount;
        require(_amount > 0, "VT3");

        // check whether the vesting cliff time has elapsed
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= _grant.vestingCliff, "VT4");

        // reset all the grant detail variables to zero
        delete vestingGrants[beneficiary_];
        // update totalVestingAmount and transfer ERC20 tokens
        totalVestingAmount = totalVestingAmount.sub(_amount);
        emit GrantClaimed(beneficiary_, _amount, block.timestamp);

        token().safeTransfer(beneficiary_, _amount);
    }

    /**
    * @dev Transfers tokens held by beneficiary to timelock.
    * @param startTime_: start time
    * @param amount_: amount
    * @param vestingCliff_: vesting cliff
    * @param beneficiary_: beneficiary address
    */
    function _addGrant(
        uint256 startTime_,
        uint256 amount_,
        uint256 vestingCliff_,    
        address benificiary_
    ) 
        internal
    {
        require(amount_ > 0, "VT5");
        require(startTime_ <= vestingCliff_, "VT6");

        // allow adding grants whose vesting schedule is already realized, so commented below line
        // require(vestingCliff_ >= block.timestamp, "VestingTimelock: vesting cliff is in the past");

        Grant memory _grant = vestingGrants[benificiary_];
        require(!_grant.isActive, "VT7");

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
    * @dev Transfers tokens held by beneficiary to timelock.
    * @param startTime_: start time
    * @param amount_: amount
    * @param vestingCliff_: vesting cliff
    * @param beneficiary_: beneficiary address
    *
    * Emits a {AddGrant} event.
    *
    */
    function addGrant(
        uint256 startTime_,
        uint256 amount_,
        uint256 vestingCliff_,    
        address benificiary_
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VT8");
        _addGrant(
            startTime_,
            amount_,
            vestingCliff_,    
            benificiary_
        );
        emit GrantAdded(benificiary_, totalVestedHistory, block.timestamp);

    }

    /**
    * @dev Transfers tokens held by beneficiary to timelock.
    * @param startTimes_: start time in array
    * @param amounts_: amount in array
    * @param vestingCliffs_: vesting cliff in array
    * @param beneficiaries: beneficiary address in array
    *
    * Emits a {GrantAdded} event.
    *
    */
    function addGrants(
        uint256[] calldata startTimes_,
        uint256[] calldata amounts_,
        uint256[] calldata vestingCliffs_,    
        address[] calldata beneficiaries
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VT9");
        require(beneficiaries.length > 0 && beneficiaries.length == amounts_.length && startTimes_.length == amounts_.length && startTimes_.length == vestingCliffs_.length, "VT10");

        // allocate the grants to the respective beneficiaries
        uint256 i;
        for (i=0; i<beneficiaries.length; i++) {
            _addGrant(
                startTimes_[i],
                amounts_[i],
                vestingCliffs_[i],    
                beneficiaries[i]
            );
        }

        // emit the data of last grant that was added
        emit GrantAdded(beneficiaries[i.sub(1)], totalVestedHistory, block.timestamp);
    }

     /**
     * @dev Transfers tokens held by beneficiary to timelock.
     * @param beneficiary_: beneficiary address
     * @param vestingProvider_: vesting provider address
     *
     */
     function _revokeGrant(address beneficiary_, address vestingProvider_) internal
    {
        Grant memory _grant = vestingGrants[beneficiary_];

        // check whether the grant is active
        require(_grant.isActive, "VT11");

        // check whether the amount is a non zero value
        uint256 _amount = _grant.amount;
        require(_amount > 0, "VT12");

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
      * @dev Transfers tokens held by beneficiary to timelock.
      * @param beneficiary_: beneficiary address
      * @param vestingProvider_: vesting provider address
      *
      * Emits a {GrantRevoked} event.
      *
      */
    function revokeGrant(address beneficiary_, address vestingProvider_) external {
        // revoke currently doesnt return the ERC20 tokens sent to this contract
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VT13");

        _revokeGrant(beneficiary_, vestingProvider_);
        emit GrantRevoked(beneficiary_, vestingProvider_, block.timestamp);
    }

    /**
      * @dev Transfers tokens held by beneficiary to timelock.
      * @param beneficiaries: beneficiary address in array
      * @param vestingProvider_: vesting provider address
      *
      * Emits a {GrantRevoked} event.
      *
      */
    function revokeGrants(
        address[] calldata beneficiaries,
        address vestingProvider_
    ) 
        external
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "VT14");
        require(beneficiaries.length > 0 , "VT15");

        // allocate the grants to the respective addresses
        uint256 i;
        for (i=0; i<beneficiaries.length; i++) {
            _revokeGrant(
                beneficiaries[i],
                vestingProvider_
            );
        }

        // emit the data of last grant that was revoked
        emit GrantRevoked(beneficiaries[i.sub(1)], vestingProvider_, block.timestamp);
    }

     /**
      * @dev Triggers stopped state.
      *
      * Requirements:
      *
      * - The contract must not be paused.
      */
    function pause() public returns (bool success) {
        require(hasRole(PAUSER_ROLE, _msgSender()), "VT16");
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
    function unpause() public returns (bool success) {
        require(hasRole(PAUSER_ROLE, _msgSender()), "VT17");
        _unpause();
        return true;
    }


    uint256[47] private __gap;
}
