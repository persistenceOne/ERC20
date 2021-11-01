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

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 * Supports multiple vesting strategies like Cliffed, Continuous, Stepped etc.
 */
contract VestingTimelockV2 is
  Initializable,
  IVestingTimelock,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable
{
  // Access Roles
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  // including libraries
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMathUpgradeable for uint256;
  using FullMath for uint256;

  // Vesting grant identifier
  uint256 _id;
  mapping(IERC20Upgradeable => uint256) _grantCount;
  mapping(IERC20Upgradeable => mapping(address => uint256)) _beneficiaryID;

  // Vesting grant parameters mapped to grant ID
  mapping(uint256 => uint256) _startTime;
  mapping(uint256 => uint256) _endTime;
  mapping(uint256 => uint256) _cliffTime;
  mapping(uint256 => address) _beneficiary;
  mapping(uint256 => bool) _isActive;
  mapping(uint256 => uint256) _instalmentAmount;
  mapping(uint256 => uint256) _instalmentCount;
  mapping(uint256 => uint256) _instalmentPeriod;
  mapping(uint256 => uint256) _amountReceived;
  mapping(uint256 => bool) _isContinuousVesting;
  // Last claimed timestamp mapped to grant ID
  mapping(uint256 => uint256) _lastClaimedTimestamp;

  /**
   * @dev Constructor for initializing the SToken contract.
   */
  function initialize(address pauserAddress_) public virtual initializer {
    __ReentrancyGuard_init();
    __AccessControl_init_unchained();
    __Pausable_init_unchained();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, pauserAddress_);
  }

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getGrant(IERC20Upgradeable token_)
    public
    view
    returns (
      uint256 startTime,
      uint256 endTime,
      uint256 cliffTime,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      bool isContinuousVesting
    )
  {
    return getGrant(token_, _msgSender());
  }

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getGrant(IERC20Upgradeable token_, address beneficiary_)
    public
    view
    returns (
      uint256 startTime,
      uint256 endTime,
      uint256 cliffTime,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      bool isContinuousVesting
    )
  {
    if (beneficiary_ == address(0)) {
      return (
        startTime,
        endTime,
        cliffTime,
        beneficiary,
        isActive,
        instalmentAmount,
        instalmentCount,
        instalmentPeriod,
        amountReceived,
        isContinuousVesting
      );
    }
    uint256 id = _beneficiaryID[token_][beneficiary_];
    return _getGrant(id);
  }

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getGrant(uint256 id_)
    public
    view
    returns (
      uint256 startTime,
      uint256 endTime,
      uint256 cliffTime,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      bool isContinuousVesting
    )
  {
    return _getGrant(id_);
  }

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function _getGrant(uint256 id_)
    internal
    view
    returns (
      uint256 startTime,
      uint256 endTime,
      uint256 cliffTime,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      bool isContinuousVesting
    )
  {
    if (id_ == 0) {
      return (
        startTime,
        endTime,
        cliffTime,
        beneficiary,
        isActive,
        instalmentAmount,
        instalmentCount,
        instalmentPeriod,
        amountReceived,
        isContinuousVesting
      );
    }

    return (
      _startTime[_id],
      _endTime[_id],
      _cliffTime[_id],
      _beneficiary[_id],
      _isActive[_id],
      _instalmentAmount[_id],
      _instalmentCount[_id],
      _instalmentPeriod[_id],
      _amountReceived[_id],
      _isContinuousVesting[_id]
    );
  }

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function _addGrant(
    uint256 id_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffTime_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) internal {
    uint256 endTime = startTime_.add(cliffTime_).add(
      instalmentPeriod_.mul(instalmentCount_.sub(1))
    );

    _startTime[id_] = startTime_;
    _endTime[id_] = endTime;
    _cliffTime[id_] = cliffTime_;
    _beneficiary[id_] = beneficiary_;
    _isActive[id_] = true;
    _instalmentAmount[id_] = instalmentAmount_;
    _instalmentCount[id_] = instalmentCount_;
    _instalmentPeriod[id_] = instalmentPeriod_;
    _isContinuousVesting[id_] = isContinuousVesting_;
  }

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function addGrantAsInstalment(
    IERC20Upgradeable token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffTime_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) public returns (uint256 totalVestingAmount) {
    // Require statements to for transaction sanity check
    require(
      beneficiary_ != (address(0)) &&
        instalmentAmount_ != 0 &&
        instalmentCount_ != 0,
      "VT1"
    );

    uint256 id = ++_id;
    _grantCount[token_]++;
    // add beneficiary to beneficiaryID
    _beneficiaryID[token_][beneficiary_] = id;

    _addGrant(
      id,
      beneficiary_,
      startTime_,
      cliffTime_,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_
    );

    emit AddGrantAsInstalment(
      id,
      token_,
      beneficiary_,
      startTime_,
      cliffTime_,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      block.timestamp
    );

    totalVestingAmount = instalmentAmount_.mul(instalmentCount_);
  }

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function addGrant(
    IERC20Upgradeable token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffTime_,
    uint256 totalAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) public returns (uint256 instalmentAmount) {
    // Require statements to for transaction sanity check
    require(
      beneficiary_ != (address(0)) &&
        totalAmount_ != 0 &&
        instalmentCount_ != 0,
      "VT2"
    );

    uint256 id = ++_id;
    _grantCount[token_]++;
    // add beneficiary to beneficiaryID
    _beneficiaryID[token_][beneficiary_] = id;
    instalmentAmount = totalAmount_.div(instalmentCount_);

    _addGrant(
      id,
      beneficiary_,
      startTime_,
      cliffTime_,
      instalmentAmount,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_
    );

    emit AddGrantAsInstalment(
      id,
      token_,
      beneficiary_,
      startTime_,
      cliffTime_,
      totalAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      block.timestamp
    );
  }

  /**
   * @notice revokeGrant tokens held by timelock to beneficiary.
   */
  function _revokeGrant(address beneficiary_, address vestingProvider_)
    internal
  {
    Grant memory _grant = vestingGrants[beneficiary_];

    // check whether the grant is active
    require(_grant.isActive, "VestingTimelock: Grant is not active");

    // check whether the amount is a non zero value
    uint256 amount = _grant.amount;
    require(amount > 0, "VestingTimelock: No tokens to revoke");

    // reset all the grant detail variables to zero
    delete vestingGrants[beneficiary_];
    totalVestingAmount = totalVestingAmount.sub(amount);
    totalVestedHistory = totalVestedHistory.sub(1);

    // transfer the erc20 token amount back to the vesting provider
    // needs to be done as there is no other means to transfer ERC20 tokens without keys.
    // except by defining custom grant for a self controlled wallet address then claiming the grant.
    token().safeTransfer(vestingProvider_, amount);
  }

  /**
   * @notice revokeGrant tokens held by timelock to beneficiary.
   */
  function revokeGrant(IERC20Upgradeable token_) public returns (uint256 id) {
    // require token address not be address(0)
    require(token_ != (address(0)), "VT4");

    id = revokeGrant(token_, _msgSender());
    emit RevokeGrant(token_, beneficiary_, block.timestamp);
  }

  /**
   * @notice revokeGrant tokens held by timelock to beneficiary.
   */
  function revokeGrant(IERC20Upgradeable token_, address beneficiary_)
    public
    returns (uint256 id)
  {
    // require beneficiary not be address(0)
    require(beneficiary_ != (address(0)), "VT3");

    id = _beneficiaryID[token_][beneficiary_];
    delete _beneficiaryID[token_][beneficiary_];

    _revokeGrant(id);
    emit RevokeGrant(token_, beneficiary_, block.timestamp);
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function claimGrant(address beneficiary_)
    external
    nonReentrant
    whenNotPaused
  {
    require(beneficiary_ == _msgSender(), "VestingTimelock: Unauthorized User");

    Grant memory _grant = vestingGrants[beneficiary_];

    // check whether the grant is active
    require(_grant.isActive, "VestingTimelock: Grant is not active");

    // check whether the amount is not zero
    uint256 amount = _grant.amount;
    require(amount > 0, "VestingTimelock: No tokens to claim");

    // check whether the vesting cliff time has elapsed
    // solhint-disable-next-line not-rely-on-time
    require(
      block.timestamp >= _grant.vestingCliff,
      "VestingTimelock: Grant still vesting"
    );

    // reset all the grant detail variables to zero
    delete vestingGrants[beneficiary_];
    // update totalVestingAmount and transfer ERC20 tokens
    totalVestingAmount = totalVestingAmount.sub(amount);
    emit GrantClaimed(beneficiary_, amount, block.timestamp);

    token().safeTransfer(beneficiary_, amount);
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function pause() public returns (bool success) {
    require(
      hasRole(PAUSER_ROLE, _msgSender()),
      "VestingTimelock: Unauthorized User"
    );
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
    require(
      hasRole(PAUSER_ROLE, _msgSender()),
      "VestingTimelock: Unauthorized User"
    );
    _unpause();
    return true;
  }

  uint256[47] private __gap;
}
