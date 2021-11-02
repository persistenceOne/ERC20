// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

/**
 * @dev Interface of the IVestingTimelockV2.
 */
interface IVestingTimelockV2 {
  /**
   * @dev get the details of the vesting grant for a user
   */
  function getGrant(address token_, address beneficiary_)
    external
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
    );

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getGrantFromID(uint256 id_)
    external
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
    );

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getPending(address token_, address beneficiary_)
    external
    view
    returns (
      uint256 pendingAmount,
      uint256 pendingTime,
      uint256 pendingInstalment
    );

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getPendingFromID(uint256 id_)
    external
    view
    returns (
      uint256 pendingAmount,
      uint256 pendingTime,
      uint256 pendingInstalment
    );

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getRemaining(address token_, address beneficiary_)
    external
    view
    returns (
      uint256 remainingAmount,
      uint256 remainingTime,
      uint256 remainingInstalment
    );

  /**
   * @dev get the details of the vesting grant for a user
   */
  function getRemainingFromID(uint256 id_)
    external
    view
    returns (
      uint256 remainingAmount,
      uint256 remainingTime,
      uint256 remainingInstalment
    );

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function addGrant(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffTime_,
    uint256 totalAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) external returns (uint256 instalmentAmount);

  /**
   * @notice Transfers tokens held by beneficiary to timelock.
   */
  function addGrantAsInstalment(
    address token_,
    address beneficiary_,
    uint256 startTime_,
    uint256 cliffTime_,
    uint256 instalmentAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_,
    bool isContinuousVesting_
  ) external returns (uint256 totalVestingAmount);

  /**
   * @notice revokeGrant tokens held by timelock to beneficiary.
   */
  function revokeGrant(
    address token_,
    address beneficiary_,
    address grantManager_
  ) external returns (uint256 remainingAmount);

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function claimGrant(address token_, address beneficiary_) external;

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function pause() external returns (bool success);

  /**
   * @dev Returns to normal state.
   *
   * Requirements:
   *
   * - The contract must be paused.
   */
  function unpause() external returns (bool success);

  event AddGrant(
    uint256 id,
    address token,
    address accountAddress,
    uint256 startTime,
    uint256 cliffTime,
    uint256 tokens,
    uint256 instalmentCount,
    uint256 instalmentPeriod,
    bool isContinuousVesting,
    address grantManager,
    uint256 timestamp
  );

  event AddGrantAsInstalment(
    uint256 id,
    address token,
    address accountAddress,
    uint256 startTime,
    uint256 cliffTime,
    uint256 tokens,
    uint256 instalmentCount,
    uint256 instalmentPeriod,
    bool isContinuousVesting,
    address grantManager,
    uint256 timestamp
  );

  event RevokeGrant(
    address token,
    address accountAddress,
    address grantManager,
    uint256 tokens,
    uint256 timestamp
  );

  event ClaimGrant(
    address token,
    address accountAddress,
    uint256 tokens,
    uint256 timestamp
  );
}
