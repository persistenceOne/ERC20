// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

/**
 * @dev Interface of the IVestingTimelockV2.
 */
interface IVestingTimelockV2 {
  /**
   * @dev Get the details of the vesting grant for a user
   * @param token_: address of token
   * @param beneficiary_: address of beneficiary
   */
  function getGrant(address token_, address beneficiary_)
    external
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
    );

  /**
   * @dev get the details of the vesting grant for a user from id
   * @param id_: vesting grant for a user id
   */
  function getGrantFromID(uint256 id_)
    external
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
    uint256 cliffPeriod_,
    uint256 totalAmount_,
    uint256 instalmentCount_,
    uint256 instalmentPeriod_
  ) external returns (uint256 instalmentAmount);

  /**
   * @notice revokeGrant tokens held by timelock to beneficiary.
   */
  function revokeGrant(address token_, address beneficiary_)
    external
    returns (uint256 remainingAmount);

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param id_: grant ID
   *
   * Emits a {RevokeGrant} event.
   */
  function revokeGrantFromID(uint256 id_)
    external
    returns (uint256 remainingAmount);

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function claimGrant(address token_, address beneficiary_)
    external
    returns (uint256 pendingAmount);

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
    uint256 cliffPeriod,
    uint256 tokens,
    uint256 instalmentAmount,
    uint256 instalmentCount,
    uint256 instalmentPeriod,
    address grantManager,
    uint256 timestamp
  );

  event RevokeGrant(
    uint256 id,
    address token,
    address sender,
    address accountAddress,
    address grantManager,
    uint256 tokens,
    uint256 timestamp
  );

  event ClaimGrant(
    uint256 id,
    address token,
    address accountAddress,
    uint256 tokens,
    uint256 timestamp
  );
}
