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
  // ID from the token and beneficiary
  mapping(address => mapping(address => uint256)) public _grantID;

  // Vesting grant parameters mapped to grant ID
  mapping(uint256 => address) _token;
  mapping(uint256 => uint256) _startTime;
  mapping(uint256 => uint256) _endTime;
  mapping(uint256 => uint256) _cliffPeriod;
  mapping(uint256 => address) _beneficiary;
  mapping(uint256 => bool) _isActive;
  mapping(uint256 => uint256) _instalmentAmount;
  mapping(uint256 => uint256) _instalmentCount;
  mapping(uint256 => uint256) _instalmentPeriod;
  mapping(uint256 => uint256) _amountReceived;
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
      address token,
      uint256 startTime,
      uint256 endTime,
      uint256 cliffPeriod,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      address grantManager
    )
  {
    if (id_ == 0) {
      return (
        token,
        startTime,
        endTime,
        cliffPeriod,
        beneficiary,
        isActive,
        instalmentAmount,
        instalmentCount,
        instalmentPeriod,
        amountReceived,
        grantManager
      );
    }

    return (
      _token[_id],
      _startTime[_id],
      _endTime[_id],
      _cliffPeriod[_id],
      _beneficiary[_id],
      _isActive[_id],
      _instalmentAmount[_id],
      _instalmentCount[_id],
      _instalmentPeriod[_id],
      _amountReceived[_id],
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
      address token,
      uint256 startTime,
      uint256 endTime,
      uint256 cliffPeriod,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
      address grantManager
    )
  {
    if (token_ == address(0) || beneficiary_ == address(0)) {
      return (
        token,
        startTime,
        endTime,
        cliffPeriod,
        beneficiary,
        isActive,
        instalmentAmount,
        instalmentCount,
        instalmentPeriod,
        amountReceived,
        grantManager
      );
    }
    uint256 id = _grantID[token_][beneficiary_];
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
      address token,
      uint256 startTime,
      uint256 endTime,
      uint256 cliffPeriod,
      address beneficiary,
      bool isActive,
      uint256 instalmentAmount,
      uint256 instalmentCount,
      uint256 instalmentPeriod,
      uint256 amountReceived,
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
    uint256 lowerTimestamp;
    uint256 higherTimestamp;

    // if the last claimed timstamp has crossed the endTime or if cliff time is not
    // crossed by _lastClaimedTimestamp[id_], return zero
    if (
      !_isActive[id_] ||
      _lastClaimedTimestamp[id_] >= _endTime[id_] ||
      _instalmentAmount[id_] <= 0 ||
      block.timestamp <= _startTime[id_].add(_cliffPeriod[id_])
    ) return (pendingAmount, pendingTime, pendingInstalment);

    higherTimestamp = (block.timestamp > _endTime[id_])
      ? _endTime[id_]
      : block.timestamp;

    lowerTimestamp = (
      _lastClaimedTimestamp[id_] < _startTime[id_]
        ? _startTime[id_]
        : _lastClaimedTimestamp[id_]
    );

    // calculate pending time between last claimed and current time, counter starting from startTime
    pendingTime = higherTimestamp.sub(lowerTimestamp);

    // calculate the pending amount
    uint256 cumulativeInstalments = _instalmentPeriod[id_] > 0
      ? (
        (
          (higherTimestamp.sub(_startTime[id_].add(_cliffPeriod[id_]))).div(
            _instalmentPeriod[id_]
          )
        ).add(1)
      )
      : 1;

    pendingAmount = (cumulativeInstalments.mul(_instalmentAmount[id_])).sub(
      _amountReceived[id_]
    );

    // calculate the pendingInstalment from the pendingAmount calculated above
    pendingInstalment = _instalmentAmount[id_] > 0
      ? pendingAmount.div(_instalmentAmount[id_])
      : 0;
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

    uint256 id = _grantID[token_][beneficiary_];
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
    // if the instalment amount is 0 then return
    if (_instalmentAmount[id_] <= 0 || _instalmentCount[id_] <= 0)
      return (remainingAmount, remainingTime, remainingInstalment);

    uint256 lastClaimedTimestamp;
    uint256 totalAmount = (_instalmentAmount[id_]).mul(_instalmentCount[id_]);

    remainingAmount = totalAmount.sub(_amountReceived[id_]);
    remainingInstalment = remainingAmount.div(_instalmentAmount[id_]);

    // get the lastClaimedTimestamp as a value inside range _startTime[id_] & _endTime[id_]
    lastClaimedTimestamp = _lastClaimedTimestamp[id_] < _startTime[id_]
      ? _startTime[id_]
      : _lastClaimedTimestamp[id_];
    lastClaimedTimestamp = lastClaimedTimestamp > _endTime[id_]
      ? _endTime[id_]
      : lastClaimedTimestamp;

    // calculate remainingTime by subtracting lastClaimedTimestamp from the end tim
    remainingTime = (_endTime[id_]).sub(lastClaimedTimestamp);
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

    uint256 id = _grantID[token_][beneficiary_];
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
   * @param token_: token contract address
   * @param beneficiary_: beneficiary address
   * @param startTime_: start time
   * @param cliffPeriod_: initial waiting period
   * @param instalmentAmount_: instalment amount
   * @param instalmentCount_: instalment count
   * @param instalmentPeriod_: instalment period
   * @param grantManager: grant manager address
   */
  function _addGrant(
    uint256 id_,
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    address grantManager
  ) internal {
    // Require statement to check if grant is already active
    require(!_isActive[id_], "VT1");

    uint256 endTime = startTime_.add(cliffPeriod_).add(
      instalmentPeriod_.mul(instalmentCount_.sub(1))
    );

    _token[id_] = token_;
    _startTime[id_] = startTime_;
    _endTime[id_] = endTime;
    _cliffPeriod[id_] = cliffPeriod_;
    _beneficiary[id_] = beneficiary_;
    _isActive[id_] = true;
    _instalmentAmount[id_] = instalmentAmount_;
    _instalmentCount[id_] = instalmentCount_;
    _instalmentPeriod[id_] = instalmentPeriod_;
    _grantManager[id_] = grantManager;
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
   * Emits a {AddGrantAsInstalment} event.
   */
  function addGrant(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffPeriod_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_
  ) public virtual override nonReentrant returns (uint256 totalVestingAmount) {
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
      "VT3"
    );

    // require instalmentPeriod to be set when the instalmentCount is more than 1
    require(!(instalmentCount_ > 1 && instalmentPeriod_ == 0), "VT18");

    // check the calling address has suffecient tokens and then transfer tokens to this contract
    totalVestingAmount = instalmentAmount_.mul(instalmentCount_);
    require(
      IERC20Upgradeable(token_).balanceOf(_msgSender()) >= totalVestingAmount,
      "VT11"
    );

    // check if the grant is not already active
    uint256 existingID = _grantID[token_][beneficiary_];
    // check if an existing active grant is not already in effect
    require(!_isActive[existingID], "VT17");

    IERC20Upgradeable(token_).safeTransferFrom(
      _msgSender(),
      address(this),
      totalVestingAmount
    );

    // generate a new id and allocate to the beneficiary
    uint256 id = ++_id;
    _grantCount[token_]++;
    // add beneficiary to beneficiaryID
    _grantID[token_][beneficiary_] = id;

    _addGrant(
      id,
      token_,
      beneficiary_,
      startTime_,
      cliffPeriod_,
      instalmentAmount_,
      instalmentCount_,
      instalmentPeriod_,
      _msgSender()
    );

    emit AddGrant(
      id,
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
   * @param id_: user id
   *
   * Emits a {AddGrantAsInstalment} event.
   */
  function _revokeGrant(uint256 id_)
    internal
    returns (uint256 remainingAmount)
  {
    // require the end date for grant to not have passed
    require(
      _isActive[id_] && _lastClaimedTimestamp[id_] < _endTime[id_],
      "VT4"
    );

    (remainingAmount, , ) = _getRemaining(id_);
    // deactivate the grant (keep other values intact)
    _isActive[id_] = false;
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
    // require beneficiary not be address(0)
    require(token_ != address(0) && beneficiary_ != (address(0)), "VT5");

    // get the ID and retrieve grantManager to compare with the msgSender()
    uint256 id = _grantID[token_][beneficiary_];
    require(id != 0, "VT7");
    address grantManager = _grantManager[id];

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT6"
    );

    // find the remaining amount after revoke and transfer it back to the grant manager
    remainingAmount = _revokeGrant(id);
    if (remainingAmount > 0) {
      // delete _grantID[token_][beneficiary_];
      IERC20Upgradeable(token_).safeTransfer(grantManager, remainingAmount);
    }

    // emit an event for record
    emit RevokeGrant(
      id,
      token_,
      _msgSender(),
      beneficiary_,
      grantManager,
      remainingAmount,
      block.timestamp
    );
  }

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param id_: grant ID
   *
   * Emits a {RevokeGrant} event.
   */
  function revokeGrantFromID(uint256 id_)
    public
    virtual
    override
    nonReentrant
    returns (uint256 remainingAmount)
  {
    require(id_ != 0, "VT15");
    // get grantManager and beneficiary
    address grantManager = _grantManager[id_];
    address beneficiary = _beneficiary[id_];

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT16"
    );

    // find the remaining amount after revoke and transfer it back to the grant manager
    remainingAmount = _revokeGrant(id_);

    if (remainingAmount > 0) {
      // delete _grantID[token_][beneficiary_];
      IERC20Upgradeable(_token[id_]).safeTransfer(
        grantManager,
        remainingAmount
      );
    }

    // emit an event for record
    emit RevokeGrant(
      id_,
      _token[id_],
      _msgSender(),
      beneficiary,
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
    // require beneficiary not be address(0)
    require(token_ != address(0) && beneficiary_ != (address(0)), "VT8");

    // get the ID and grant manager from the grant data
    uint256 id = _grantID[token_][beneficiary_];
    require(id != 0, "VT9");
    address grantManager = _grantManager[id];

    // Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN defined in the contract
    require(
      _msgSender() == beneficiary_ ||
        _msgSender() == grantManager ||
        hasRole(GRANT_ADMIN_ROLE, _msgSender()),
      "VT10"
    );

    // require the grant to be active and vesting amount still pending to be credited to beneficiary for claiming
    require(
      _isActive[id] &&
        (_instalmentAmount[id].mul(_instalmentCount[id]) > _amountReceived[id]),
      "VT12"
    );

    // get the pending amount to be credited to beneficiary
    (pendingAmount, , ) = _getPending(id);

    if (pendingAmount > 0) {
      IERC20Upgradeable(token_).safeTransfer(beneficiary_, pendingAmount);
      _amountReceived[id] = _amountReceived[id].add(pendingAmount);

      // set last claimed for the grant to current time
      _lastClaimedTimestamp[id] = block.timestamp;
    }

    // if all the vesting amount has been claimed, then deactivate grant
    if (block.timestamp >= _endTime[id]) {
      _isActive[id] = false;
    }

    emit ClaimGrant(id, token_, beneficiary_, pendingAmount, block.timestamp);
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
