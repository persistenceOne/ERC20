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
import "./libraries/FullMath.sol";
import "./interfaces/IVestingTimelockV3.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 * Supports multiple vesting strategies like Cliffed, Continuous, Stepped etc.
 */
contract VestingTimelockV3 is
  Initializable,
  IVestingTimelockV3,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable
{
  // including libraries
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMathUpgradeable for uint256;
  using FullMath for uint256;

  // Access Roles
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant GRANT_ADMIN_ROLE = keccak256("GRANT_ADMIN_ROLE");

  // variable pertaining to contract upgrades versioning
  uint256 public _version;

  // mapping(address => uint256) public _grantCount;

  // Vesting grant parameters (tightly packed)
  struct Grant {
    bool isActive;
    uint32 cliffPeriod;
    uint32 instalmentPeriod;
    uint48 startTime;
    uint48 endTime;
    uint48 lastClaimedTime;
    uint40 instalmentCount;
    uint256 instalmentAmount;
    uint256 amountReceived;
    address grantManager;
  }

  // ID from the token and beneficiary
  mapping(address => mapping(address => Grant)) public override _grantData;

  /**
   * @dev Constructor for initializing the Vesting Timelock contract.
   * @param pauserAddress_ - address of the pauser admin.
   * @param grantAdminAddress_ - address of the grant admin.
   */
  function initialize(address pauserAddress_, address grantAdminAddress_)
    public
    virtual
    initializer
  {
    __ReentrancyGuard_init();
    __AccessControl_init_unchained();
    __Pausable_init_unchained();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, pauserAddress_);
    _setupRole(GRANT_ADMIN_ROLE, grantAdminAddress_);
  }

  /**
   * @dev Get the details of the vesting grant for a user
   * @param token_: address of token
   * @param beneficiary_: address of beneficiary
   */
  /* function getGrant(address token_, address beneficiary_)
    public
    view
    virtual
    override
    returns (
      uint256 startTime,
      uint256 endTime,
      uint256 cliffPeriod,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      address grantManager,
      uint256 lastClaimedTime
    )
  {
    if (token_ != address(0) && beneficiary_ != address(0)) {}
    Grant memory grant = _grantData[token_][beneficiary_];
    return (
      uint256(grant.startTime),
      uint256(grant.endTime),
      uint256(grant.cliffPeriod),
      grant.isActive,
      uint256(grant.instalmentAmount),
      uint256(grant.instalmentCount),
      uint256(grant.instalmentPeriod),
      uint256(grant.amountReceived),
      grant.grantManager,
      uint256(grant.lastClaimedTime)
    );
  } */

  /**
   * @dev calculate the pending time in the currently vesting installment
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   */
  function getPending(address token_, address beneficiary_)
    public
    view
    virtual
    override
    returns (
      uint256 pendingAmount,
      uint256 pendingTime,
      uint256 pendingInstalment
    )
  {
    if (token_ == address(0) || beneficiary_ == address(0))
      return (pendingAmount, pendingTime, pendingInstalment);

    uint256 lowerTimestamp;
    uint256 higherTimestamp;
    Grant memory grant = _grantData[token_][beneficiary_];
    uint256 vestingStartTime = uint256(grant.startTime).add(
      uint256(grant.cliffPeriod)
    );

    // if the last claimed timstamp has crossed the endTime or if cliff time is not
    // crossed by _lastClaimedTime[id_], return zero
    if (
      !grant.isActive ||
      grant.lastClaimedTime >= grant.endTime ||
      grant.instalmentAmount <= 0 ||
      block.timestamp <= vestingStartTime
    ) return (pendingAmount, pendingTime, pendingInstalment);

    higherTimestamp = (block.timestamp > uint256(grant.endTime))
      ? uint256(grant.endTime)
      : block.timestamp;

    lowerTimestamp = (
      grant.lastClaimedTime < grant.startTime
        ? uint256(grant.startTime)
        : uint256(grant.lastClaimedTime)
    );

    // calculate pending time between last claimed and current time, counter starting from startTime
    pendingTime = higherTimestamp.sub(lowerTimestamp);

    // calculate the pending amount
    uint256 cumulativeInstalments = grant.instalmentPeriod > 0
      ? (
        (
          (higherTimestamp.sub(vestingStartTime)).div(
            uint256(grant.instalmentPeriod)
          )
        ).add(1)
      )
      : 1;

    pendingAmount = (cumulativeInstalments.mul(grant.instalmentAmount)).sub(
      grant.amountReceived
    );

    // calculate the pendingInstalment from the pendingAmount calculated above
    pendingInstalment = grant.instalmentAmount > 0
      ? pendingAmount.div(grant.instalmentAmount)
      : 0;
  }

  /**
   * @dev calculate the remaining amount
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   */
  function getRemaining(address token_, address beneficiary_)
    public
    view
    virtual
    override
    returns (
      uint256 remainingAmount,
      uint256 remainingTime,
      uint256 remainingInstalment
    )
  {
    if (token_ == address(0) || beneficiary_ == address(0))
      return (remainingAmount, remainingTime, remainingInstalment);

    Grant memory grant = _grantData[token_][beneficiary_];
    // if the instalment amount is 0 then return
    if (grant.instalmentAmount <= 0 || grant.instalmentCount <= 0)
      return (remainingAmount, remainingTime, remainingInstalment);

    uint256 lastClaimedTime;
    uint256 totalAmount = (grant.instalmentAmount).mul(
      uint256(grant.instalmentCount)
    );

    remainingAmount = totalAmount.sub(grant.amountReceived);
    remainingInstalment = remainingAmount.div(grant.instalmentAmount);

    // get the lastClaimedTime as a value inside range grant.startTime & grant.endTime
    lastClaimedTime = uint256(grant.lastClaimedTime) < uint256(grant.startTime)
      ? uint256(grant.startTime)
      : uint256(grant.lastClaimedTime);
    lastClaimedTime = lastClaimedTime > uint256(grant.endTime)
      ? uint256(grant.endTime)
      : lastClaimedTime;

    // calculate remainingTime by subtracting lastClaimedTime from the end tim
    remainingTime = uint256(grant.endTime).sub(lastClaimedTime);
  }

  /**
   * @dev Transfers tokens held by beneficiary to timelock in installments
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   * @param startTime_: start time
   * @param cliffPeriod_: initial waiting period
   * @param instalmentAmount_: installment amount
   * @param instalmentCount_: instalment count
   * @param instalmentPeriod_: instalment period
   *
   * Emits a {AddGrant} event.
   */
  function addGrant(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_
  )
    public
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (uint256 totalVestingAmount)
  {
    // Require statements to for transaction sanity check
    require(
      token_ != address(0) &&
        beneficiary_ != (address(0)) &&
        // max limit of cliff period is 10 years (in seconds)
        cliffPeriod_ < (3650 days) &&
        // min range for start time starts from 10 years in the past
        startTime_ > ((block.timestamp).sub(3650 days)) &&
        // max range for start time starts from 10 years in the future
        startTime_ < ((block.timestamp).add(3650 days)) &&
        instalmentAmount_ > 0 &&
        instalmentCount_ > 0 &&
        instalmentCount_ < 1200 &&
        // max limit of instalment period is 10 years (in seconds)
        instalmentPeriod_ < (3650 days),
      "VT1"
    );

    // check instalmentPeriod to be set when the instalmentCount is more than 1
    require(!(instalmentCount_ > 1 && instalmentPeriod_ == 0), "VT2");

    // check the calling address has sufficient tokens and then transfer tokens to this contract
    totalVestingAmount = instalmentAmount_.mul(instalmentCount_);
    require(
      IERC20Upgradeable(token_).balanceOf(_msgSender()) >= totalVestingAmount,
      "VT3"
    );

    // check if the grant is not already active
    // Grant memory grant = _grantData[token_][beneficiary_];
    // check if an existing active grant is not already in effect
    require(!_grantData[token_][beneficiary_].isActive, "VT4");

    IERC20Upgradeable(token_).safeTransferFrom(
      _msgSender(),
      address(this),
      totalVestingAmount
    );

    uint48 endTime = uint48(
      startTime_.add(cliffPeriod_).add(
        instalmentPeriod_.mul(instalmentCount_.sub(1))
      )
    );

    // create a new grant and set it to the mapping
    Grant memory newGrant;
    newGrant.startTime = uint48(startTime_);
    newGrant.endTime = endTime;
    newGrant.cliffPeriod = uint32(cliffPeriod_);
    newGrant.isActive = true;
    newGrant.instalmentAmount = instalmentAmount_;
    newGrant.instalmentCount = uint40(instalmentCount_);
    newGrant.instalmentPeriod = uint32(instalmentPeriod_);
    newGrant.grantManager = _msgSender();
    _grantData[token_][beneficiary_] = newGrant;

    emit AddGrant(
      token_,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      totalVestingAmount,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      _msgSender(),
      block.timestamp
    );
  }

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   *
   * Emits a {RevokeGrant} event.
   */
  function revokeGrant(address token_, address beneficiary_)
    public
    virtual
    override
    nonReentrant
    returns (uint256 remainingAmount)
  {
    // check beneficiary not be address(0)
    require(token_ != address(0) && beneficiary_ != (address(0)), "VT5");

    Grant storage grant = _grantData[token_][beneficiary_];
    address grantManager = grant.grantManager;

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT6"
    );

    // find the remaining amount after revoke and transfer it back to the grant manager
    // check the end date for grant to not have passed
    require(grant.isActive && grant.lastClaimedTime < grant.endTime, "VT7");

    (remainingAmount, , ) = getRemaining(token_, beneficiary_);
    // deactivate the grant (keep other values intact)
    grant.isActive = false;

    if (remainingAmount > 0) {
      // delete _grantID[token_][beneficiary_];
      IERC20Upgradeable(token_).safeTransfer(grantManager, remainingAmount);
    }

    // emit an event for record
    emit RevokeGrant(
      token_,
      _msgSender(),
      beneficiary_,
      grantManager,
      remainingAmount,
      block.timestamp
    );
  }

  /**
   * @dev Transfers tokens held by timelock to beneficiary.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   *
   * Emits a {ClaimGrant} event.
   */
  function claimGrant(address token_, address beneficiary_)
    external
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (uint256 pendingAmount)
  {
    // check beneficiary not be address(0)
    require(token_ != address(0) && beneficiary_ != (address(0)), "VT8");

    // get the grant manager from the grant data
    Grant storage grant = _grantData[token_][beneficiary_];
    address grantManager = grant.grantManager;

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT9"
    );

    // check the grant to be active and vesting amount still pending to be credited to beneficiary for claiming
    require(
      grant.isActive &&
        (grant.instalmentAmount.mul(uint256(grant.instalmentCount)) >
          grant.amountReceived),
      "VT10"
    );

    // get the pending amount to be credited to beneficiary
    (pendingAmount, , ) = getPending(token_, beneficiary_);

    if (pendingAmount > 0) {
      IERC20Upgradeable(token_).safeTransfer(beneficiary_, pendingAmount);
      grant.amountReceived = grant.amountReceived.add(pendingAmount);

      // set last claimed for the grant to current time
      grant.lastClaimedTime = uint48(block.timestamp);
    }

    // if all the vesting amount has been claimed, then deactivate grant
    if (block.timestamp >= uint256(grant.endTime)) {
      grant.isActive = false;
    }

    emit ClaimGrant(token_, beneficiary_, pendingAmount, block.timestamp);
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function pause() public virtual override returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "VT11");
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
  function unpause() public virtual override returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "VT12");
    _unpause();
    return true;
  }
}
