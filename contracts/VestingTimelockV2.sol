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
import "./interfaces/IVestingTimelockV2.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 * Supports multiple vesting strategies like Cliffed, Continuous, Stepped etc.
 */
contract VestingTimelockV2 is
  Initializable,
  IVestingTimelockV2,
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

  // Vesting grant identifier
  uint256 public _id;
  mapping(address => uint256) public _grantCount;
  mapping(address => mapping(address => uint256)) public _beneficiaryID;

  // Vesting grant parameters mapped to grant ID
  mapping(uint256 => uint256) _startTime;
  mapping(uint256 => uint256) _endTime;
  mapping(uint256 => uint256) _cliffPeriod;
  mapping(uint256 => address) _beneficiary;
  mapping(uint256 => bool) _isActive;
  mapping(uint256 => uint256) _instalmentAmount;
  mapping(uint256 => uint256) _instalmentCount;
  mapping(uint256 => uint256) _instalmentPeriod;
  mapping(uint256 => uint256) _amountReceived;
  mapping(uint256 => bool) _isContinuousVesting;
  mapping(uint256 => address) _grantManager;

  // Last claimed timestamp mapped to grant ID
  mapping(uint256 => uint256) public _lastClaimedTimestamp;

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
   * @param id_: vesting grant user id
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
      bool isContinuousVesting,
      address grantManager
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
        isContinuousVesting,
        grantManager
      );
    }

    return (
      _startTime[_id],
      _endTime[_id],
      _cliffPeriod[_id],
      _beneficiary[_id],
      _isActive[_id],
      _instalmentAmount[_id],
      _instalmentCount[_id],
      _instalmentPeriod[_id],
      _amountReceived[_id],
      _isContinuousVesting[_id],
      _grantManager[_id]
    );
  }

  /**
   * @dev Get the details of the vesting grant for a user
   * @param token_: address of token
   * @param beneficiary_: address of beneficiary
   */
  function getGrant(address token_, address beneficiary_)
    public
    view
    virtual
    override
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
      bool isContinuousVesting,
      address grantManager
    )
  {
    if (token_ == address(0) || beneficiary_ == address(0)) {
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
        isContinuousVesting,
        grantManager
      );
    }
    uint256 id = _beneficiaryID[token_][beneficiary_];
    return _getGrant(id);
  }

  /**
   * @dev get the details of the vesting grant for a user from id
   * @param id_: vesting grant for a user id
   */
  function getGrantFromID(uint256 id_)
    public
    view
    virtual
    override
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
      bool isContinuousVesting,
      address grantManager
    )
  {
    return _getGrant(id_);
  }

  /**
   * @dev calculate the pending time in the currently vesting installment
   * @param id_: vesting grant for a user id
   */
  function _getPending(uint256 id_)
    internal
    view
    returns (
      uint256 pendingAmount,
      uint256 pendingTime,
      uint256 pendingInstalment
    )
  {
    uint256 lastClaimedTimestamp = _lastClaimedTimestamp[id_];
    uint256 instalmentPeriodRemainder;
    uint256 lowerTimestamp;
    uint256 higherTimestamp;
    uint256 pendingVestingTime;

    // if cliff time is not crossed by lastClaimedTimestamp, return the full amount and instalment count
    if (block.timestamp <= _startTime[id_].add(_cliffPeriod[id_])) {
      return (pendingAmount, pendingTime, pendingInstalment);
    }

    // if the last claimed timstamp has crossed the endTime, return zero
    if (!_isActive[id_] || lastClaimedTimestamp >= _endTime[id_])
      return (pendingAmount, pendingTime, pendingInstalment);

    lowerTimestamp = (lastClaimedTimestamp <
      _startTime[id_].add(_cliffPeriod[id_]))
      ? _startTime[id_].add(_cliffPeriod[id_])
      : lastClaimedTimestamp;

    higherTimestamp = (block.timestamp > _endTime[id_])
      ? _endTime[id_]
      : block.timestamp;

    lastClaimedTimestamp = (
      lastClaimedTimestamp < _startTime[id_]
        ? _startTime[id_]
        : lastClaimedTimestamp
    );

    // calculate pending time between last claimed and current time
    pendingTime = higherTimestamp.sub(lastClaimedTimestamp);
    pendingVestingTime = higherTimestamp.sub(lowerTimestamp);

    // calculate the pending time in the currently vesting instalment
    instalmentPeriodRemainder = pendingVestingTime.mod(_instalmentPeriod[id_]);

    // calculate pendingAmount as per vesting mode
    if (_isContinuousVesting[id_]) {
      // _instalmentPeriod[id_] zero condition need not be checked as it would come under already elapsed grant's end time
      if (lowerTimestamp > _startTime[id_].add(_cliffPeriod[id_])) {
        pendingInstalment = (instalmentPeriodRemainder > 0)
          ? (pendingVestingTime.div(_instalmentPeriod[id_])).add(1)
          : (pendingVestingTime.div(_instalmentPeriod[id_]));
      } else {
        pendingInstalment = (instalmentPeriodRemainder > 0)
          ? (pendingVestingTime.div(_instalmentPeriod[id_])).add(2)
          : (pendingVestingTime.div(_instalmentPeriod[id_])).add(1);
      }

      // pending amount will contain the amount pro-rated to the time diff component also, along with the pendingInstalment
      pendingAmount = (instalmentPeriodRemainder > 0)
        ? (
          (
            instalmentPeriodRemainder.mulDiv(
              _instalmentAmount[id_],
              _instalmentPeriod[id_]
            )
          ).add((pendingInstalment.sub(1)).mul(_instalmentAmount[id_]))
        )
        : (pendingInstalment.mul(_instalmentAmount[id_]));
    } else {
      // _instalmentPeriod[id_] zero condition need not be checked as it would come under already elapsed grant's end time
      if (lowerTimestamp > _startTime[id_].add(_cliffPeriod[id_])) {
        pendingInstalment = (pendingVestingTime.div(_instalmentPeriod[id_]));
      } else {
        pendingInstalment = (pendingVestingTime.div(_instalmentPeriod[id_]))
          .add(1);
      }

      // pending amount will be directly derived from pendingInstalment
      pendingAmount = pendingInstalment.mul(_instalmentAmount[id_]);
    }
  }

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

    uint256 id = _beneficiaryID[token_][beneficiary_];
    (pendingAmount, pendingTime, pendingInstalment) = _getPending(id);
  }

  /**
   * @dev calculate the pending time in the currently vesting installment from user id
   * @param id_: user id
   */
  function getPendingFromID(uint256 id_)
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
    if (id_ == 0) return (pendingAmount, pendingTime, pendingInstalment);
    (pendingAmount, pendingTime, pendingInstalment) = _getPending(id_);
  }

  /**
   * @dev calculate the remaining amount
   * @param id_: user id
   */
  function _getRemaining(uint256 id_)
    internal
    view
    returns (
      uint256 remainingAmount,
      uint256 remainingTime,
      uint256 remainingInstalment
    )
  {
    uint256 lastClaimedTimestamp = _lastClaimedTimestamp[id_];
    uint256 instalmentPeriodRemainder;

    // if cliff time is not crossed by lastClaimedTimestamp, return the full amount and instalment count
    if (lastClaimedTimestamp <= _startTime[id_].add(_cliffPeriod[id_])) {
      return (
        _instalmentAmount[id_].mul(_instalmentCount[id_]),
        _endTime[id_].sub(lastClaimedTimestamp),
        _instalmentCount[id_]
      );
    }

    // if the last claimed timstamp has crossed the endTime, return zero
    if (!_isActive[id_] || lastClaimedTimestamp >= _endTime[id_])
      return (remainingAmount, remainingTime, remainingInstalment);

    // if cliff time is crossed then calculate the remaining data by taking the ratio
    remainingTime = _endTime[id_].sub(lastClaimedTimestamp);

    // calculate the remaining time in the currently vesting instalment
    instalmentPeriodRemainder = remainingTime.mod(_instalmentPeriod[id_]);

    // calculate remainingAmount as per vesting mode
    if (_isContinuousVesting[id_]) {
      // _instalmentPeriod[id_] zero condition need not be checked as it would come under already elapsed grant's end time
      remainingInstalment = (remainingTime.div(_instalmentPeriod[id_]));

      remainingAmount = (instalmentPeriodRemainder > 0)
        ? (
          (
            instalmentPeriodRemainder.mulDiv(
              _instalmentAmount[id_],
              _instalmentPeriod[id_]
            )
          ).add((remainingInstalment).mul(_instalmentAmount[id_]))
        )
        : (remainingInstalment.mul(_instalmentAmount[id_]));
    } else {
      // _instalmentPeriod[id_] zero condition need not be checked as it would come under already elapsed grant's end time
      remainingInstalment = (instalmentPeriodRemainder > 0)
        ? (remainingTime.div(_instalmentPeriod[id_])).add(1)
        : (remainingTime.div(_instalmentPeriod[id_]));

      remainingAmount = remainingInstalment.mul(_instalmentAmount[id_]);
    }
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

    uint256 id = _beneficiaryID[token_][beneficiary_];
    (remainingAmount, remainingTime, remainingInstalment) = _getRemaining(id);
  }

  /**
   * @dev calculate the remaining amount from user id
   * @param id_: user id
   */
  function getRemainingFromID(uint256 id_)
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
    if (id_ == 0) return (remainingAmount, remainingTime, remainingInstalment);
    (remainingAmount, remainingTime, remainingInstalment) = _getRemaining(id_);
  }

  /**
   * @dev Transfers tokens held by beneficiary to timelock.
   * @param id_: user id
   * @param beneficiary_: beneficiary address
   * @param startTime_: start time
   * @param cliffPeriod_: initial waiting period
   * @param instalmentAmount_: instalment amount
   * @param instalmentCount_: instalment count
   * @param instalmentPeriod_: instalment period
   * @param isContinuousVesting_: vesting required or not
   * @param grantManager: grant manager address
   */
  function _addGrant(
    uint256 id_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_,
    address grantManager
  ) internal {
    // Require statement to check if grant is already active
    require(!_isActive[id_], "VT1");
    uint256 endTime = startTime_.add(cliffPeriod_).add(
      instalmentPeriod_.mul(instalmentCount_.sub(1))
    );

    _startTime[id_] = startTime_;
    _endTime[id_] = endTime;
    _cliffPeriod[id_] = cliffPeriod_;
    _beneficiary[id_] = beneficiary_;
    _isActive[id_] = true;
    _instalmentAmount[id_] = instalmentAmount_;
    _instalmentCount[id_] = instalmentCount_;
    _instalmentPeriod[id_] = instalmentPeriod_;
    _isContinuousVesting[id_] = isContinuousVesting_;
    _grantManager[id_] = grantManager;
  }

  /**
   * @dev Transfers tokens held by beneficiary to timelock.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   * @param startTime_: start time
   * @param cliffPeriod_: initial waiting period
   * @param totalAmount_: amount
   * @param instalmentCount_: instalment count
   * @param instalmentPeriod_: instalment period
   * @param isContinuousVesting_: vesting required or not
   *
   * Emits a {AddGrant} event.
   */
  function addGrant(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 totalAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) public virtual override nonReentrant returns (uint256 instalmentAmount) {
    // Require statements to for transaction sanity check
    require(
      token_ != address(0) &&
        beneficiary_ != address(0) &&
        totalAmount_ != 0 &&
        instalmentCount_ != 0,
      "VT2"
    );

    // check the calling address has sufficient tokens and then transfer tokens to this contract
    instalmentAmount = totalAmount_.div(instalmentCount_);

    require(
      IERC20Upgradeable(token_).balanceOf(_msgSender()) >= totalAmount_,
      "VT13"
    );

    IERC20Upgradeable(token_).safeTransferFrom(
      _msgSender(),
      address(this),
      totalAmount_
    );

    // generate a new id and allocate to the beneficiary
    uint256 id = ++_id;
    _grantCount[token_]++;
    // add beneficiary to beneficiaryID
    _beneficiaryID[token_][beneficiary_] = id;

    _addGrant(
      id,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      instalmentAmount,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      _msgSender()
    );

    emit AddGrant(
      id,
      token_,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      totalAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      _msgSender(),
      block.timestamp
    );
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
   * @param isContinuousVesting_: vesting required or not
   *
   * Emits a {AddGrantAsInstalment} event.
   */
  function addGrantAsInstalment(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) public virtual override nonReentrant returns (uint256 totalVestingAmount) {
    // Require statements to for transaction sanity check
    require(
      token_ != address(0) &&
        beneficiary_ != (address(0)) &&
        instalmentAmount_ != 0 &&
        instalmentCount_ != 0,
      "VT3"
    );

    // check the calling address has suffecient tokens and then transfer tokens to this contract
    totalVestingAmount = instalmentAmount_.mul(instalmentCount_);

    require(
      IERC20Upgradeable(token_).balanceOf(_msgSender()) >= totalVestingAmount,
      "VT11"
    );

    IERC20Upgradeable(token_).safeTransferFrom(
      _msgSender(),
      address(this),
      totalVestingAmount
    );

    // generate a new id and allocate to the beneficiary
    uint256 id = ++_id;
    _grantCount[token_]++;
    // add beneficiary to beneficiaryID
    _beneficiaryID[token_][beneficiary_] = id;

    _addGrant(
      id,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      _msgSender()
    );

    emit AddGrantAsInstalment(
      id,
      token_,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      isContinuousVesting_,
      _msgSender(),
      block.timestamp
    );
  }

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param id_: user id
   *
   * Emits a {AddGrantAsInstalment} event.
   */
  function _revokeGrant(uint256 id_)
    internal
    returns (uint256 remainingAmount)
  {
    // require the end date for grant to not have passed
    require(_isActive[id_] && _endTime[id_] > block.timestamp, "VT4");

    (remainingAmount, , ) = _getRemaining(id_);
    // deactivate the grant (keep other values intact)
    _isActive[id_] = false;
  }

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   * @param grantManager_: grant manager address
   *
   * Emits a {RevokeGrant} event.
   */
  function revokeGrant(
    address token_,
    address beneficiary_,
    address grantManager_
  ) public virtual override nonReentrant returns (uint256 remainingAmount) {
    // require beneficiary not be address(0)
    require(
      token_ != address(0) &&
        beneficiary_ != (address(0)) &&
        grantManager_ != address(0),
      "VT5"
    );

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager_ ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT6"
    );

    // get the ID and delete corresponding _beneficiaryID value
    uint256 id = _beneficiaryID[token_][beneficiary_];
    require(id != 0, "VT7");

    // find the remaining amount after revoke and transfer it back to the grant manager
    remainingAmount = _revokeGrant(id);
    assert(
      remainingAmount <= IERC20Upgradeable(token_).balanceOf(address(this))
    );

    if (remainingAmount > 0) {
      // delete _beneficiaryID[token_][beneficiary_];
      IERC20Upgradeable(token_).safeTransfer(grantManager_, remainingAmount);
    }

    // emit an event for record
    emit RevokeGrant(
      token_,
      beneficiary_,
      grantManager_,
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
  {
    // require beneficiary not be address(0)
    require(token_ != address(0) && beneficiary_ != (address(0)), "VT8");

    // get the ID and grant manager from the grant data
    uint256 id = _beneficiaryID[token_][beneficiary_];
    require(id != 0, "VT9");
    address grantManager = _grantManager[id];

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT10"
    );

    // require the grant to be active and vesting amount still pening to be credited to beneficiary for claiming
    require(
      _isActive[id] &&
        (_instalmentAmount[id].mul(_instalmentCount[id]) > _amountReceived[id]),
      "VT12"
    );

    // get the pending amount to be credited to beneficiary
    (uint256 pendingAmount, , ) = _getPending(id);

    if (pendingAmount > 0) {
      IERC20Upgradeable(token_).safeTransfer(beneficiary_, pendingAmount);
      _amountReceived[id] = _amountReceived[id].add(pendingAmount);
    }

    // set last claimed for the grant to current time
    _lastClaimedTimestamp[id] = block.timestamp;

    // if all the vesting amount has been claimed, then deactivate grant
    if (block.timestamp >= _endTime[id]) {
      _isActive[id] = false;
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
  function unpause() public virtual override returns (bool success) {
    require(
      hasRole(PAUSER_ROLE, _msgSender()),
      "VestingTimelock: Unauthorized User"
    );
    _unpause();
    return true;
  }
}
