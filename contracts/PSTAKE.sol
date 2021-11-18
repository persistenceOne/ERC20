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
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

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
  uint256 public _inflationPeriod;
  uint256 public _lastInflationBlockTime;
  uint256 public _supplyMaxLimit;

  // constants for value allocation
  uint256 public constant INFLATION_RATE = uint256(15e7);
  uint256 public constant INFLATION_PERIOD = 365 days;
  uint256 public constant VALUE_DIVISOR = uint256(1e9);
  uint256 public constant SUPPLY_AT_GENESIS = uint256(500000000e18);
  uint256 public constant TOTAL_VESTED_SUPPLY = uint256(450111111e18);
  uint256 public constant SUPPLY_MAX_LIMIT = uint256(1250000000e18);

  // pre-allocate tokens to strategy pools
  uint256 public constant AIRDROPPOOLALLOCATION = uint256(5000000e18);
  uint256 public constant ALPHALAUNCHPADPOOLALLOCATION = uint256(10000000e18);
  uint256 public constant INCENTIVISATIONPOOLALLOCATION = uint256(13222222e18);
  uint256 public constant XPRTSTAKERSPOOLALLOCATION = uint256(1250000e18);
  uint256 public constant PROTOCOLTREASURYPOOLALLOCATION = uint256(4250000e18);
  uint256 public constant COMMUNITYDEVELOPMENTFUNDPOOLALLOCATION =
    uint256(1666667e18);
  uint256 public constant RETROACTIVEREWARDPROTOCOLBOOTSTRAPPOOLALLOCATION =
    uint256(14500000e18);

  /**
   * @dev Constructor for initializing the PSTAKE contract.
   * @param vestingTimelockAddress - address of the vesting timelock contract.
   * @param airdropPool - address of the airdrop pool.
   * @param alphaLaunchpadPool - address of the alpha launchpad pool.
   * @param seedSalePool - address of the seed sale pool.
   * @param publicSalePool1 - address of the public sale pool1.
   * @param publicSalePool2 - address of the public sale pool2.
   * @param publicSalePool3 - address of the public sale pool3.
   * @param teamPool - address of the team pool.
   * @param incentivisationPool - address of the incentivising pool.
   * @param xprtStakersPool - address of the xprt stakers pool.
   * @param protocolTreasuryPool - address of the protocol treasury pool.
   * @param communityDevelopmentFundPool - address of the community development fund pool.
   * @param retroactiveRewardProtocolBootstrapPool - address of the retroactive reward protocol bootstrap pool.
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
    _setupRole(MINTER_ROLE, _msgSender());

    // setup the version and vesting timelock contract
    _version = 1;
    _vestingTimelockAddress = vestingTimelockAddress;
    // PSTAKE is an erc20 token hence 18 decimal places
    _setupDecimals(18);
    _valueDivisor = VALUE_DIVISOR;
    // _inflationRate = INFLATION_RATE;
    // _inflationPeriod = INFLATION_PERIOD;
    // _lastInflationBlockTime = block.timestamp;
    _totalInflatedSupply = uint256(SUPPLY_AT_GENESIS);
    _supplyMaxLimit = SUPPLY_MAX_LIMIT;
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
    _mint(_airdropPool, AIRDROPPOOLALLOCATION);
    _mint(_alphaLaunchpadPool, ALPHALAUNCHPADPOOLALLOCATION);
    _mint(_incentivisationPool, INCENTIVISATIONPOOLALLOCATION);
    _mint(_xprtStakersPool, XPRTSTAKERSPOOLALLOCATION);
    _mint(_protocolTreasuryPool, PROTOCOLTREASURYPOOLALLOCATION);
    _mint(
      _communityDevelopmentFundPool,
      COMMUNITYDEVELOPMENTFUNDPOOLALLOCATION
    );
    _mint(
      _retroactiveRewardProtocolBootstrapPool,
      RETROACTIVEREWARDPROTOCOLBOOTSTRAPPOOLALLOCATION
    );

    // accumulate tokens to allocate for vesting strategies (total supply - initial circulating supply)
    mint(address(this), TOTAL_VESTED_SUPPLY);

    // approve the vesting timelock contract to pull the tokens
    _approve(address(this), _vestingTimelockAddress, TOTAL_VESTED_SUPPLY);

    // ALLOCATING VESTING STRATEGIES

    /* // airdrop pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _airdropPool,
      block.timestamp,
      (30 days + 10 hours),
      uint256(5000000e18),
      5,
      (30 days + 10 hours)
    );

    // seedSale pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _seedSalePool,
      block.timestamp,
      // 6 months
      (182 days + 12 hours),
      uint256(8333333e18),
      12,
      (30 days + 10 hours)
    );

    // publicSalePool1 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _publicSalePool1,
      block.timestamp,
      // 6 months
      (182 days + 12 hours),
      uint256(833333e18),
      6,
      (30 days + 10 hours)
    );

    // publicSalePool2 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _publicSalePool2,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(1666667e18),
      6,
      (30 days + 10 hours)
    );

    // publicSalePool3 pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _publicSalePool3,
      block.timestamp,
      (30 days + 10 hours),
      uint256(10000000e18),
      1,
      0
    );

    // team pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _teamPool,
      block.timestamp,
      // 18 months
      (547 days + 12 hours),
      uint256(4444444e18),
      18,
      (30 days + 10 hours)
    );

    // incentivisation pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _incentivisationPool,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(13222222e18),
      8,
      // 3 months
      (91 days + 6 hours)
    );

    // xprtStakers pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _xprtStakersPool,
      block.timestamp,
      (30 days + 10 hours),
      uint256(1250000e18),
      11,
      (30 days + 10 hours)
    );

    // protocolTreasury pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _protocolTreasuryPool,
      block.timestamp,
      // 2 months
      (60 days + 20 hours),
      uint256(4250000e18),
      17,
      // 2 months
      (60 days + 20 hours)
    );

    // communityDevelopmentFund pool
    IVestingTimelockV2(_vestingTimelockAddress).addGrant(
      address(this),
      _communityDevelopmentFundPool,
      block.timestamp,
      // 3 months
      (91 days + 6 hours),
      uint256(1666667e18),
      17,
      // 3 months
      (91 days + 6 hours)
    ); */
  }

  /**
   * @dev Check inflation
   * Emits a {CheckInflation} event with 'block height', 'inflationComponent', and 'timestamp'.
   *
   */
  function _checkInflation() internal returns (uint256 totalInflatedSupply) {
    // if the _totalInflatedSupply has already reacted _supplyMaxLimit or inflation properties not set, then return
    if (
      _totalInflatedSupply >= _supplyMaxLimit ||
      _inflationRate == 0 ||
      _inflationPeriod == 0
    ) return (totalInflatedSupply);

    // get the time since last inflation
    uint256 timeSinceLastInflation = (block.timestamp).sub(
      _lastInflationBlockTime
    );

    // get the inflation amount for one cycle of inflation period
    uint256 inflationPerInstalment = uint256(SUPPLY_AT_GENESIS).mulDiv(
      _inflationRate,
      _valueDivisor
    );

    // get the number of cycles/instalments of inflation that are pending to be updated
    uint256 inflationInstalments = timeSinceLastInflation.div(_inflationPeriod);
    uint256 additionalInflation = inflationInstalments.mul(
      inflationPerInstalment
    );
    uint256 additionalBlockTime = inflationInstalments.mul(_inflationPeriod);

    if (inflationInstalments > 0) {
      // add inflationPerInstalment to total inflated supply
      uint256 inflationDiff = _supplyMaxLimit.sub(_totalInflatedSupply);
      _totalInflatedSupply = _totalInflatedSupply.add(additionalInflation);

      if (_totalInflatedSupply > _supplyMaxLimit) {
        // set totalInflatedSupply as supply max limit
        _totalInflatedSupply = _supplyMaxLimit;
        _lastInflationBlockTime = 0;

        // update the _lastInflationBlockTime value
        uint256 blockTimeDiff = additionalBlockTime.mulDiv(
          inflationDiff,
          additionalInflation
        );
        _lastInflationBlockTime = _lastInflationBlockTime.add(blockTimeDiff);
      } else {
        // update _lastInflationBlockTime with the time period pertaining to inflationInstalments
        _lastInflationBlockTime = _lastInflationBlockTime.add(
          additionalBlockTime
        );
      }

      // emit an event
      emit CheckInflation(
        _lastInflationBlockTime,
        inflationInstalments.mul(_inflationPeriod),
        block.timestamp
      );
    }

    totalInflatedSupply = _totalInflatedSupply;
  }

  /**
   * @dev Set inflation
   * @param inflationRate: inflation rate.
   *
   */
  function setInflation(uint256 inflationRate, uint256 inflationPeriod)
    public
    virtual
    override
    returns (bool success)
  {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS0");
    // require inflation rate to be not more than 100 since it is a percentage
    require(inflationRate <= _valueDivisor, "PS7");
    require(inflationPeriod > 0, "PS9");
    // after enabling inflation, one way to arrest inflation can be to set a large inflationPeriod value
    _inflationRate = inflationRate;
    _inflationPeriod = inflationPeriod;
    // if this is the first time inflation values are being set (inflation activation) then
    // initialize _totalInflatedSupply with the inflated value and update _lastInflationBlockTime
    // the inflation cycle begins just as these values are set
    if (_lastInflationBlockTime == 0) {
      _totalInflatedSupply = _totalInflatedSupply.add(
        _totalInflatedSupply.mulDiv(_inflationRate, _valueDivisor)
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
   */
  function setSupplyMaxLimit(uint256 supplyMaxLimit)
    public
    virtual
    override
    returns (bool success)
  {
    // require this function to be callable only by the admin
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS8");
    // new supply max limit cannot be less than _totalInflatedSupply
    require(supplyMaxLimit >= _totalInflatedSupply, "PS10");
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
    require(hasRole(MINTER_ROLE, _msgSender()), "PS1");

    // condition to check if the total supply doesnt cross the inflated supply
    _checkInflation();
    require((totalSupply()).add(tokens) <= _totalInflatedSupply, "PS2");

    // mint the tokens
    _mint(to, tokens);
    return true;
  }

  /**
   * @dev Set 'contract address', called from constructor
   * @param vestingTimelockAddress: Vesting timelock contract address
   *
   * Emits a {SetVestingTimelockContract} event with '_contract' set to the VestingTimelockcontract address.
   */
  function setVestingTimelockContract(address vestingTimelockAddress)
    public
    virtual
    override
  {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS6");
    require(vestingTimelockAddress != address(0), "PS11");
    _vestingTimelockAddress = vestingTimelockAddress;
    emit SetVestingTimelockContract(vestingTimelockAddress);
  }

  /**
   * @dev adds a vesting grant initiated by this contract as manager
   * @param beneficiary beneficiary address
   * @param startTime start time
   * @param cliffPeriod initial waiting period
   * @param instalmentAmount installment amount
   * @param instalmentCount instalment count
   * @param instalmentPeriod instalment period
   *
   * Emits a {AddGrantAsInstalment} event.
   */
  function addVesting(
    address beneficiary,
    uint256 startTime,
    uint256 cliffPeriod,
    uint256 instalmentAmount,
    uint256 instalmentCount,
    uint256 instalmentPeriod
  ) public virtual override nonReentrant returns (uint256 totalVestingAmount) {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "PS12");

    totalVestingAmount = IVestingTimelockV2(_vestingTimelockAddress).addGrant(
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
