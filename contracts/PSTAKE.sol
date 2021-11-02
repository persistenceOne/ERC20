// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./libraries/FullMath.sol";
import "./interfaces/IVestingTimelockV2.sol";
import "./interfaces/IPSTAKE.sol";

contract PSTAKE is
  IPSTAKE,
  ERC20Upgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable
{
  // including libraries
  using SafeMathUpgradeable for uint256;
  using FullMath for uint256;

  // constants defining access control ROLES
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  // variable pertaining to contract upgrades versioning and value divisor
  uint256 public _version;
  uint256 public _valueDivisor;

  // addresses pertaining to various tokenomics strategy
  address public _airdropPool;
  address public _alphaLaunchpadPool;
  address public _seedSalePool;
  address public _publicSalePool1;
  address public _publicSalePool2;
  address public _publicSalePool3;
  address public _teamPool;
  address public _incentivisationPool;
  address public _xprtStakersPool;
  address public _protocolTreasuryPool;
  address public _communityDevelopmentFundPool;
  address public _retroactiveRewardProtocolBootstrapPool;

  // address of vesting timelock contract to enable several vesting strategy
  address public _vestingTimelockAddress;

  // total inflated supply and the supply limit component to implement inflation
  uint256 public _totalInflatedSupply;
  uint256 public _inflationRate;
  uint256 public _lastInflationBlockHeight;
  uint256 public constant SUPPLY_AT_GENESIS = uint256(500000000e18);
  uint256 public constant BLOCKS_PER_YEAR = uint256(2407328);

  /**
   * @dev Constructor for initializing the UToken contract.
   */
  function initialize(
    address vestingTimelockAddress,
    address airdropPool,
    address alphaLaunchpadPool,
    address seedSalePool,
    address publicSalePool1,
    address publicSalePool2,
    address publicSalePool3,
    address teamPool,
    address incentivisationPool,
    address xprtStakersPool,
    address protocolTreasuryPool,
    address communityDevelopmentFundPool,
    address retroactiveRewardProtocolBootstrapPool
  ) public virtual initializer {
    __ERC20_init("pSTAKE Token", "PSTAKE");
    __AccessControl_init();
    __Pausable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, _msgSender());

    // PSTAKE is an erc20 token hence 18 decimal places
    _setupDecimals(18);
    _inflationRate = uint256(15e9);
    _valueDivisor = uint256(1e9);
    _lastInflationBlockHeight = block.number;
    _totalInflatedSupply = uint256(500000000e18);

    // setup the version and vesting timelock contract
    _version = 1;
    _vestingTimelockAddress = vestingTimelockAddress;

    // allocate the various tokenomics strategy pool addresses
    // (must be different addresses because each address can have only one active vesting strategy at a time)
    _airdropPool = airdropPool;
    _alphaLaunchpadPool = alphaLaunchpadPool;
    _seedSalePool = seedSalePool;
    _publicSalePool1 = publicSalePool1;
    _publicSalePool2 = publicSalePool2;
    _publicSalePool3 = publicSalePool3;
    _teamPool = teamPool;
    _incentivisationPool = incentivisationPool;
    _xprtStakersPool = xprtStakersPool;
    _protocolTreasuryPool = protocolTreasuryPool;
    _communityDevelopmentFundPool = communityDevelopmentFundPool;
    _retroactiveRewardProtocolBootstrapPool = retroactiveRewardProtocolBootstrapPool;

    // pre-allocate tokens to strategy pools
    _mint(_airdropPool, uint256(5000000e18));
    _mint(_alphaLaunchpadPool, uint256(10000000e18));
    _mint(_incentivisationPool, uint256(13222222e18));
    _mint(_xprtStakersPool, uint256(1250000e18));
    _mint(_protocolTreasuryPool, uint256(4250000e18));
    _mint(_communityDevelopmentFundPool, uint256(1666667e18));
    _mint(_retroactiveRewardProtocolBootstrapPool, uint256(14500000e18));

    // accumulate tokens to allocate for vesting strategies (total supply - initial circulating supply)
    mint(address(this), uint256(448541666e18));

    // approve the vesting timelock contract to pull the tokens
    _approve(address(this), _vestingTimelockAddress, uint256(450111111e18));
    // create vesting strategies

    // airdrop pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _airdropPool,
      block.timestamp,
      // 1 month
      (30 days + 10 hours),
      uint256(5000000e18),
      5,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // seedSale pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _seedSalePool,
      block.timestamp,
      // 6 months
      (182 days + 12 hours),
      uint256(8333333e18),
      12,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // publicSalePool1 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _publicSalePool1,
      block.timestamp,
      // 6 months
      (182 days + 12 hours),
      uint256(833333e18),
      6,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // publicSalePool2 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _publicSalePool2,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(1666667e18),
      6,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // publicSalePool3 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _publicSalePool3,
      block.timestamp,
      // 1 month
      (30 days + 10 hours),
      uint256(10000000e18),
      1,
      // 0 month
      0,
      false
    );

    // team pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _teamPool,
      block.timestamp,
      // 18 months
      (547 days + 12 hours),
      uint256(4444444e18),
      18,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // incentivisation pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _incentivisationPool,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(13222222e18),
      8,
      // 3 months
      (91 days + 6 hours),
      false
    );

    // xprtStakers pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _xprtStakersPool,
      block.timestamp,
      // 1 month
      (30 days + 10 hours),
      uint256(1250000e18),
      11,
      // 1 month
      (30 days + 10 hours),
      false
    );

    // protocolTreasury pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _protocolTreasuryPool,
      block.timestamp,
      // 2 months
      (60 days + 20 hours),
      uint256(4250000e18),
      17,
      // 2 months
      (60 days + 20 hours),
      false
    );

    // communityDevelopmentFund pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrantAsInstalment(
      address(this),
      _communityDevelopmentFundPool,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(1666667e18),
      17,
      // 3 months
      (91 days + 6 hours),
      false
    );
  }

  /**
   * @dev A token holder contract that will allow a beneficiary to extract
   */
  function checkInflation() public virtual override returns (bool success) {
    if (_lastInflationBlockHeight.add(BLOCKS_PER_YEAR) <= block.number) {
      // add inflation component to total inflated supply
      uint256 inflationComponent = uint256(SUPPLY_AT_GENESIS).mulDiv(
        _inflationRate,
        _valueDivisor
      );
      _totalInflatedSupply = _totalInflatedSupply.add(inflationComponent);
      _lastInflationBlockHeight = block.number;
      emit CheckInflation(
        _lastInflationBlockHeight.add(BLOCKS_PER_YEAR),
        inflationComponent,
        block.timestamp
      );
    }
    success = true;
  }

  /**
   * @dev A token holder contract that will allow a beneficiary to extract
   */
  function setInflation(uint256 inflationRate)
    public
    virtual
    override
    returns (bool success)
  {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS0");
    _inflationRate = inflationRate;
    success = true;
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
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS1");
    // condition to check if the total supply doesnt cross the inflated supply
    checkInflation();
    require((totalSupply()).add(tokens) <= _totalInflatedSupply, "PS2");

    // mint the tokens
    _mint(to, tokens);
    return true;
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function pause() public virtual override returns (bool success) {
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
  function unpause() public virtual override returns (bool success) {
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
