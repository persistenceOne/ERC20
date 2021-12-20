/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

pragma solidity >=0.7.0;

/**
 * @dev Interface of the IVestingTimelockV2.
 */
interface IVestingTimelockV3 {
  /**
   * @dev Get the details of the vesting grant for a user
   * @param token_: address of token
   * @param beneficiary_: address of beneficiary
   */
  function _grantData(address token_, address beneficiary_)
    external
    returns (
      bool isActive,
      uint32 cliffPeriod,
      uint32 instalmentPeriod,
      uint48 startTime,
      uint48 endTime,
      uint48 lastClaimedTime,
      uint40 instalmentCount,
      uint256 instalmentAmount,
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
  function getRemaining(address token_, address beneficiary_)
    external
    view
    returns (
      uint256 remainingAmount,
      uint256 remainingTime,
      uint256 remainingInstalment
    );

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
  ) external returns (uint256 totalVestingAmount);

  /**
   * @dev Revoke grant tokens held by timelock to beneficiary.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   *
   * Emits a {RevokeGrant} event.
   */
  function revokeGrant(address token_, address beneficiary_)
    external
    returns (uint256 remainingAmount);

  /**
   * @dev Transfers tokens held by timelock to beneficiary.
   * @param token_: token address
   * @param beneficiary_: beneficiary address
   *
   * Emits a {ClaimGrant} event.
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

  /**
   * @dev Emitted when grant is added
   */
  event AddGrant(
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

  /**
   * @dev Emitted when grant is revoked
   */
  event RevokeGrant(
    address token,
    address sender,
    address accountAddress,
    address grantManager,
    uint256 tokens,
    uint256 timestamp
  );

  /**
   * @dev Emitted when grant is claimed
   */
  event ClaimGrant(
    address token,
    address accountAddress,
    uint256 tokens,
    uint256 timestamp
  );
}
