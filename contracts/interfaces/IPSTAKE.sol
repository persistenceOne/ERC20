// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface of the IPSTAKE.
 */
interface IPSTAKE is IERC20Upgradeable {
  /**
   * @dev A token holder contract that will allow a beneficiary to extract
   */
  function checkInflation() external returns (bool success);

  /**
   * @dev A token holder contract that will allow a beneficiary to extract
   */
  function setInflation(uint256 inflationRate) external returns (bool success);

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
   * Emits a {SetVestingTimelockContract} event with '_contract' set to the VestingTimelockcontract address.
   */
  function setVestingTimelockContract(address vestingTimelockAddress) external;

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

  event CheckInflation(
    uint256 blockHeight,
    uint256 inflationComponent,
    uint256 timestamp
  );

  event SetVestingTimelockContract(address vestingTimelockAddress);
}
