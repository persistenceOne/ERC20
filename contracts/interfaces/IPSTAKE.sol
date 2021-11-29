// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface of the IPSTAKE.
 */
interface IPSTAKE is IERC20Upgradeable {

  /**
   * @dev getter method created from variable definition
   *
   */
  function _lastInflationBlockTime()
    external
    view
    returns (uint256 lastInflationBlockTime);

  /**
   * @dev getter method created from variable definition
   *
   */
  function _totalInflatedSupply()
    external
    view
    returns (uint256 totalInflatedSupply);

  /**
   * @dev getter method created from variable definition
   *
   */
  function _supplyMaxLimit() external view returns (uint256 supplyMaxLimit);

  /**
   * @dev checks the inflation and sets the inflation parameters if the inflation cycle has changed
   *
   */
  function checkInflation()
    external
    returns (uint256 totalInflatedSupply, uint256 lastInflationBlockTime);

  /**
   * @dev returns the properties pertaining to inflation
   */
  function getInflation()
    external
    view
    returns (
      uint256 totalInflatedSupply,
      uint256 inflationRate,
      uint256 valueDivisor,
      uint256 inflationPeriod,
      uint256 lastInflationBlockTime,
      uint256 supplyMaxLimit
    );

   /**
    * @dev Set inflation
    * @param inflationRate: inflation rate given as value between 0 and 100
    * @param inflationPeriod: inflation cycle in seconds
    *
    * Emits a {SetInflationRate} event.
    *
    */
  function setInflation(uint256 inflationRate, uint256 inflationPeriod)
    external
    returns (bool success);

  /**
   * @dev Set supply max limit of the inflation component
   * @param supplyMaxLimit: supply max limit value
   *
   * Emits a {SetSupplyMaxLimit} event.
   *
   */
  function setSupplyMaxLimit(uint256 supplyMaxLimit)
    external
    returns (bool success);

  /**
   * @dev Mints `amount` tokens to the caller's address `to`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function mint(address to, uint256 tokens) external returns (bool success);

  /**
   * @dev Set 'contract address', called from constructor
   * @param vestingTimelockAddress: VestingTimelockcontract address
   *
   * Emits a {SetVestingTimelockContract} event with '_contract' set to the VestingTimelockcontract address.
   *
   */
  function setVestingTimelockContract(address vestingTimelockAddress) external;

  /**
   * @dev adds a vesting grant initiated by this contract as manager
   * @param beneficiary: beneficiary address
   * @param startTime: start time
   * @param cliffPeriod: initial waiting period
   * @param instalmentAmount: installment amount
   * @param instalmentCount: instalment count
   * @param instalmentPeriod: instalment period
   */
  function addVesting(
    address beneficiary,
    uint256 startTime,
    uint256 cliffPeriod,
    uint256 instalmentAmount,
    uint256 instalmentCount,
    uint256 instalmentPeriod
  ) external returns (uint256 totalVestingAmount);

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
   * @dev Emitted when checkInflation() is called
   */
  event CheckInflation(
    uint256 lastInflationBlockTime,
    uint256 inflationAdded,
    uint256 timestamp
  );

  /**
   * @dev Emitted when setting vesting timelock contract address
   */
  event SetVestingTimelockContract(address vestingTimelockAddress);

  /**
   * @dev Emitted when setting inflation rate
   */
  event SetInflationRate(
    address accountAddress,
    uint256 inflationRate,
    uint256 inflationPeriod
  );

  /**
   * @dev Emitted when setting max limit supply
   */
  event SetSupplyMaxLimit(address accountAddress, uint256 supplyMaxLimit);
}
