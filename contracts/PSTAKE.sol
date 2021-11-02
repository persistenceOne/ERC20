// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IVestingTimelockV2.sol";

contract PSTAKE is
  IPSTAKE,
  ERC20Upgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
{
  // including libraries
  using SafeMathUpgradeable for uint256;
  using FullMath for uint256;

  // constants defining access control ROLES
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  // variable pertaining to contract upgrades versioning
  uint256 public _version;

  // addresses pertaining to various tokenomics strategy
  address public _airdropPool;
  address public _seedSalePool;
  address public _strategicFoundationSalePool;
  address public _teamPool;
  address public _incentivisationPool;
  address public _xprtStakersPool;
  address public _protocolTreasuryPool;
  address public _communityDevelopmentFundPool;

  // address of vesting timelock contract to enable several vesting strategy
  address public _vestingTimelockAddress;

  /**
   * @dev Constructor for initializing the UToken contract.
   * @param pauserAddress - address of the pauser admin.
   */
  function initialize(
    address pauserAddress,
    address vestingTimelockAddress,
    address airdropPool,
    address seedSalePool,
    address strategicFoundationSalePool,
    address teamPool,
    address incentivisationPool,
    address xprtStakersPool,
    address protocolTreasuryPool,
    address communityDevelopmentFundPool
  ) public virtual initializer {
    __ERC20_init("pSTAKE Token", "PSTAKE");
    __AccessControl_init();
    __Pausable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, pauserAddress);
    // PSTAKE IS A SIMPLE ERC20 TOKEN HENCE 18 DECIMAL PLACES
    _setupDecimals(18);
    // setup the version and vesting timelock contract
    _version = 1;
    _vestingTimelockAddress = vestingTimelockAddress;
    // allocate the various tokenomics strategy pool addresses
    _airdropPool = airdropPool;
    _seedSalePool = seedSalePool;
    _strategicFoundationSalePool = strategicFoundationSalePool;
    _teamPool = teamPool;
    _incentivisationPool = incentivisationPool;
    _xprtStakersPool = xprtStakersPool;
    _protocolTreasuryPool = protocolTreasuryPool;
    _communityDevelopmentFundPool = communityDevelopmentFundPool;
    // pre-allocate tokens to strategy pools
    _mint(_airdropPool, uint256(20000000e18));
    _mint(_incentivisationPool, uint256(20000000e18));
    _mint(_xprtStakersPool, uint256(2083334e18));
    _mint(_protocolTreasuryPool, uint256(6250000e18));
    _mint(_communityDevelopmentFundPool, uint256(3125000e18));
  }

  /**
   * @dev Mint new PSTAKE for the provided 'address' and 'amount'
   *
   *
   * Emits a {MintTokens} event with 'to' set to address and 'tokens' set to amount of tokens.
   *
   * Requirements:
   *
   * - `amount` cannot be less than zero.
   *
   */
  function mint(address to, uint256 tokens)
    public
    virtual
    override
    returns (bool success)
  {
    require(_msgSender() == _stakeLPCoreContract, "PS1"); // minted by STokens contract

    _mint(to, tokens);
    return true;
  }

  /*
   * @dev Burn utokens for the provided 'address' and 'amount'
   * @param from: account address, tokens: number of tokens
   *
   * Emits a {BurnTokens} event with 'from' set to address and 'tokens' set to amount of tokens.
   *
   * Requirements:
   *
   * - `amount` cannot be less than zero.
   *
   */
  function burn(address from, uint256 tokens)
    public
    virtual
    override
    returns (bool success)
  {
    require(
      (tx.origin == from && _msgSender() == _liquidStakingContract) || // staking operation
        (tx.origin == from && _msgSender() == _wrapperContract),
      "PS2"
    ); // unwrap operation
    _burn(from, tokens);
    return true;
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function pause() public virtual returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "PS3");
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
  function unpause() public virtual returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "PS4");
    _unpause();
    return true;
  }

  /**
   * @dev Hook that is called before any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * will be to transferred to `to`.
   * - when `from` is zero, `amount` tokens will be minted for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
   * - `from` and `to` are never both zero.
   *
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    require(!paused(), "PS5");
    super._beforeTokenTransfer(from, to, amount);
  }
}
