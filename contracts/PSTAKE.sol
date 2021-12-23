/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./libraries/FullMath.sol";
import "./interfaces/IVestingTimelockV3.sol";
import "./interfaces/IPSTAKE.sol";

contract PSTAKE is
  IPSTAKE,
  ERC20Upgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable
{
  // including libraries
  using SafeMathUpgradeable for uint256;
  using FullMath for uint256;

  // constants defining access control ROLES
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // variable pertaining to contract upgrades versioning and value divisor
  uint256 public _version;
  uint256 public _valueDivisor;

  // addresses pertaining to various tokenomics strategy
  address public _airdropPool;
  address public _alphaLaunchpadPool;
  address public _publicSalePool;
  address public _incentivisationCommunityDevelopmentPool;
  address public _xprtStakersPool;
  address public _protocolTreasuryPool;
  address public _retroactiveRewardProtocolBootstrapPool;

  // address of vesting timelock contract to enable several vesting strategy
  address public _vestingTimelockAddress;

  // total inflated supply and the supply limit component to implement inflation
  uint256 public override _totalInflatedSupply;
  uint256 public _inflationRate;
  uint256 public _inflationPeriod;
  uint256 public override _lastInflationBlockTime;
  uint256 public override _supplyMaxLimit;

  // constants for value allocation
  uint256 public constant VALUE_DIVISOR = uint256(1e9);
  uint256 public constant INFLATION_RATE = uint256(15e9);
  uint256 public constant INFLATION_PERIOD = 365 days;
  uint256 public constant SUPPLY_AT_GENESIS = uint256(500000000e18);
  uint256 public constant TOTAL_VESTED_SUPPLY = uint256(441944444e18);
  uint256 public constant SUPPLY_MAX_LIMIT = uint256(1250000000e18);

  // pre-allocate tokens to strategy pools
  uint256 public constant AIRDROPPOOLALLOCATION = uint256(5000000e18);
  uint256 public constant ALPHALAUNCHPADPOOLALLOCATION = uint256(10000000e18);
  uint256 public constant PUBLICSALEPOOLALLOCATION = uint256(6250000e18);
  uint256 public constant INCENTIVISATIONCOMMUNITYDEVELOPMENTPOOLALLOCATION =
    uint256(14444444e18);
  uint256 public constant XPRTSTAKERSPOOLALLOCATION = uint256(1250000e18);
  uint256 public constant PROTOCOLTREASURYPOOLALLOCATION = uint256(11111111e18);
  uint256 public constant RETROACTIVEREWARDPROTOCOLBOOTSTRAPPOOLALLOCATION =
    uint256(10000000e18);

  /**
   * @dev Constructor for initializing the PSTAKE contract.
   * @param vestingTimelockAddress - address of the vesting timelock contract.
   * @param airdropPool - address of the airdrop pool.
   * @param alphaLaunchpadPool - address of the alpha launchpad pool.
   * @param publicSalePool - address of the public sale pool1.
   * @param incentivisationCommunityDevelopmentPool - address of the incentivising pool.
   * @param xprtStakersPool - address of the xprt stakers pool.
   * @param protocolTreasuryPool - address of the protocol treasury pool.
   * @param retroactiveRewardProtocolBootstrapPool - address of the retroactive reward protocol bootstrap pool.
   */
  function initialize(
    address vestingTimelockAddress,
    address airdropPool,
    address alphaLaunchpadPool,
    address publicSalePool,
    address incentivisationCommunityDevelopmentPool,
    address xprtStakersPool,
    address protocolTreasuryPool,
    address retroactiveRewardProtocolBootstrapPool
  ) public virtual initializer {
    __ERC20_init("pSTAKE Token", "PSTAKE");
    __AccessControl_init();
    __Pausable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());

    // setup the version and vesting timelock contract
    _version = 1;
    _vestingTimelockAddress = vestingTimelockAddress;
    // PSTAKE is an erc20 token hence 18 decimal places
    _setupDecimals(18);
    _valueDivisor = VALUE_DIVISOR;
    _totalInflatedSupply = uint256(SUPPLY_AT_GENESIS);
    _airdropPool = airdropPool;
    _alphaLaunchpadPool = alphaLaunchpadPool;
    _publicSalePool = publicSalePool;
    _incentivisationCommunityDevelopmentPool = incentivisationCommunityDevelopmentPool;
    _xprtStakersPool = xprtStakersPool;
    _protocolTreasuryPool = protocolTreasuryPool;
    _retroactiveRewardProtocolBootstrapPool = retroactiveRewardProtocolBootstrapPool;

    // pre-allocate tokens to strategy pools
    _mint(_airdropPool, AIRDROPPOOLALLOCATION);
    _mint(_alphaLaunchpadPool, ALPHALAUNCHPADPOOLALLOCATION);
    _mint(_publicSalePool, PUBLICSALEPOOLALLOCATION);
    _mint(
      _incentivisationCommunityDevelopmentPool,
      INCENTIVISATIONCOMMUNITYDEVELOPMENTPOOLALLOCATION
    );
    _mint(_xprtStakersPool, XPRTSTAKERSPOOLALLOCATION);
    _mint(_protocolTreasuryPool, PROTOCOLTREASURYPOOLALLOCATION);
    _mint(
      _retroactiveRewardProtocolBootstrapPool,
      RETROACTIVEREWARDPROTOCOLBOOTSTRAPPOOLALLOCATION
    );

    // accumulate tokens to allocate for vesting strategies (total supply - initial circulating supply)
    mint(address(this), TOTAL_VESTED_SUPPLY);
  }

  /**
   * @dev Check inflation
   * Emits a {CheckInflation} event with 'block height', 'inflationComponent', and 'timestamp'.
   *
   */
  function _checkInflation()
    internal
    returns (uint256 totalInflatedSupply, uint256 lastInflationBlockTime)
  {
    // if the _totalInflatedSupply has already reacted _supplyMaxLimit or inflation properties not set, then return
    if (
      _totalInflatedSupply >= _supplyMaxLimit ||
      _inflationRate == 0 ||
      _inflationPeriod == 0
    ) return (_totalInflatedSupply, _lastInflationBlockTime);

    // get the time since last inflation
    uint256 timeSinceLastInflation = (block.timestamp).sub(
      _lastInflationBlockTime
    );

    // get the inflation amount for one cycle of inflation period
    uint256 inflationPerInstalment = (
      uint256(SUPPLY_AT_GENESIS).mulDiv(_inflationRate, _valueDivisor)
    ).div(100);

    // get the number of cycles/instalments of inflation that are pending to be updated
    uint256 inflationInstalments = timeSinceLastInflation.div(_inflationPeriod);
    uint256 additionalInflation = inflationInstalments.mul(
      inflationPerInstalment
    );

    if (inflationInstalments > 0) {
      // if adding additionalInflation to _totalInflatedSupply crosses _supplyMaxLimit then make _totalInflatedSupply as _supplyMaxLimit
      _totalInflatedSupply = _totalInflatedSupply.add(additionalInflation) >
        _supplyMaxLimit
        ? _supplyMaxLimit
        : _totalInflatedSupply.add(additionalInflation);
      /* process if (_totalInflatedSupply > _supplyMaxLimit) */
      _lastInflationBlockTime = _lastInflationBlockTime.add(
        _inflationPeriod.mul(inflationInstalments)
      );

      // emit an event
      emit CheckInflation(
        _lastInflationBlockTime,
        additionalInflation,
        block.timestamp
      );
    }

    // get the return values
    lastInflationBlockTime = _lastInflationBlockTime;
    totalInflatedSupply = _totalInflatedSupply;
  }

  /**
   * @dev checks the inflation and sets the inflation parameters if the inflation cycle has changed
   *
   */
  function checkInflation()
    public
    virtual
    override
    returns (uint256 totalInflatedSupply, uint256 lastInflationBlockTime)
  {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS1");
    (totalInflatedSupply, lastInflationBlockTime) = _checkInflation();
  }

  /**
   * @dev returns the properties pertaining to inflation
   */
  function getInflation()
    public
    view
    virtual
    override
    returns (
      uint256 totalInflatedSupply,
      uint256 inflationRate,
      uint256 valueDivisor,
      uint256 inflationPeriod,
      uint256 lastInflationBlockTime,
      uint256 supplyMaxLimit
    )
  {
    return (
      _totalInflatedSupply,
      _inflationRate,
      _valueDivisor,
      _inflationPeriod,
      _lastInflationBlockTime,
      _supplyMaxLimit
    );
  }

  /**
   * @dev Set inflation
   * @param inflationRate: inflation rate given as value between 0 and 100
   * @param inflationPeriod: inflation cycle in seconds
   *
   * Emits a {SetInflationRate} event.
   *
   */
  function setInflation(uint256 inflationRate, uint256 inflationPeriod)
    public
    virtual
    override
    returns (bool success)
  {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS2");
    // check inflation rate to be not more than 100 since it is a percentage
    require(inflationRate <= _valueDivisor.mul(100), "PS3");
    require(inflationPeriod > 0, "PS4");
    // execute check inflation to update the inflation values before setting the inflation
    _checkInflation();
    // after enabling inflation, one way to arrest inflation can be to set a large inflationPeriod value
    _inflationRate = inflationRate;
    _inflationPeriod = inflationPeriod;
    // if this is the first time inflation values are being set (inflation activation) then
    // initialize _totalInflatedSupply with the inflated value and update _lastInflationBlockTime
    // the inflation cycle begins just as these values are set
    if (_lastInflationBlockTime == 0) {
      _totalInflatedSupply = _totalInflatedSupply.add(
        (_totalInflatedSupply.mulDiv(_inflationRate, _valueDivisor)).div(100)
      );
      _lastInflationBlockTime = block.timestamp;
    }
    success = true;
    emit SetInflationRate(_msgSender(), inflationRate, inflationPeriod);
  }

  /**
   * @dev Set supply max limit of the inflation component
   * @param supplyMaxLimit: supply max limit value
   *
   * Emits a {SetSupplyMaxLimit} event.
   *
   */
  function setSupplyMaxLimit(uint256 supplyMaxLimit)
    public
    virtual
    override
    returns (bool success)
  {
    // check this function to be callable only by the admin
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS5");
    // new supply max limit cannot be less than _totalInflatedSupply
    require(supplyMaxLimit >= _totalInflatedSupply, "PS6");
    // execute check inflation to update the inflation values before setting the inflation
    _checkInflation();
    // if the total inflated supply has already reached supply max limit then update _lastInflationBlockTime
    // to restart the inflation cycle again
    if (_supplyMaxLimit == _totalInflatedSupply) {
      _lastInflationBlockTime = block.timestamp;
    }
    _supplyMaxLimit = supplyMaxLimit;
    success = true;
    emit SetSupplyMaxLimit(_msgSender(), supplyMaxLimit);
  }

  /**
   * @dev Mint new PSTAKE for the provided 'address' and 'amount'
   *
   * Emits a {Transfer} event with 'to' set to address and 'tokens' set to amount of tokens.
   */
  function mint(address to, uint256 tokens)
    public
    virtual
    override
    returns (bool success)
  {
    require(hasRole(MINTER_ROLE, _msgSender()), "PS7");

    // condition to check if the total supply doesnt cross the inflated supply
    _checkInflation();
    require((totalSupply()).add(tokens) <= _totalInflatedSupply, "PS8");

    // mint the tokens
    _mint(to, tokens);
    return true;
  }

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
  ) public virtual override nonReentrant returns (uint256 totalVestingAmount) {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS11");

    totalVestingAmount = instalmentAmount.mul(instalmentCount);

    // get approval for transfer of total vesting amount if not already there
    if (totalVestingAmount > allowance(address(this), _vestingTimelockAddress))
      _approve(address(this), _vestingTimelockAddress, totalVestingAmount);

    IVestingTimelockV3(_vestingTimelockAddress).addGrant(
      address(this),
      beneficiary,
      startTime,
      cliffPeriod,
      instalmentAmount,
      instalmentCount,
      instalmentPeriod
    );
  }

  /**
   * @dev Triggers stopped state.
   *
   *
   * - The contract must not be paused.
   */
  function pause() public virtual override returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "PS12");
    _pause();
    return true;
  }

  /**
   * @dev Returns to normal state.
   *
   *
   * - The contract must be paused.
   */
  function unpause() public virtual override returns (bool success) {
    require(hasRole(PAUSER_ROLE, _msgSender()), "PS13");
    _unpause();
    return true;
  }

  /**
   * @dev Hook that is called before any transfer of tokens. This includes
   * minting and burning.
   *
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    require(!paused(), "PS14");
    super._beforeTokenTransfer(from, to, amount);
  }
}
