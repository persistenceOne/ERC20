const VestingTimelockV2Artifact = artifacts.require("VestingTimelockV2");
const PSTAKEArtifact = artifacts.require("PSTAKE");
var networkID;

const { BN } = web3.utils.BN;
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
var PSTAKEInstance;

module.exports = async function (deployer, network, accounts) {
  if (network === "development") {
    let gasPriceGanache = 3e10;
    let gasLimitGanache = 800000;
    networkID = 5777;
    await deployContract(gasPriceGanache, gasLimitGanache, deployer, accounts);
  }

  if (network === "ropsten") {
    let gasPriceRopsten = 1e11;
    let gasLimitRopsten = 5000000;
    networkID = 3;
    await deployContract(gasPriceRopsten, gasLimitRopsten, deployer, accounts);
  }

  if (network === "goerli") {
    let gasPriceGoerli = 5e12;
    let gasLimitGoerli = 4000000;
    networkID = 5;
    await deployContract(gasPriceGoerli, gasLimitGoerli, deployer, accounts);
  }

  if (network === "mainnet") {
    let gasPriceMainnet = 5e10;
    let gasLimitMainnet = 7000000;
    networkID = 1;
    await deployContract(gasPriceMainnet, gasLimitMainnet, deployer, accounts);
  }
};

async function deployContract(gasPrice, gasLimit, deployer, accounts) {
  console.log(
    "inside deployContract(),",
    " gasPrice: ",
    gasPrice,
    " gasLimit: ",
    gasLimit,
    " deployer: ",
    deployer.network,
    " accounts: ",
    accounts
  );
  // init parameters
  // let pauseAdmin = accounts[0];
  // let from_defaultAdmin = accounts[0];
  let airdropPool = accounts[1];
  let alphaLaunchpadPool = accounts[2];
  let seedSalePool = accounts[3];
  let publicSalePool1 = accounts[4];
  let publicSalePool2 = accounts[5];
  let publicSalePool3 = accounts[6];
  let teamPool = accounts[7];
  let incentivisationPool = accounts[8];
  let xprtStakersPool = accounts[9];
  let protocolTreasuryPool = accounts[10];
  let communityDevelopmentFundPool = accounts[11];
  let retroactiveRewardProtocolBootstrapPool = accounts[12];

  console.log("Vesting Timelock address: ", VestingTimelockV2Artifact.address);

  PSTAKEInstance = await deployProxy(
    PSTAKEArtifact,
    [
      VestingTimelockV2Artifact.address,
      airdropPool,
      alphaLaunchpadPool,
      seedSalePool,
      publicSalePool1,
      publicSalePool2,
      publicSalePool3,
      teamPool,
      incentivisationPool,
      xprtStakersPool,
      protocolTreasuryPool,
      communityDevelopmentFundPool,
      retroactiveRewardProtocolBootstrapPool,
    ],
    { deployer, initializer: "initialize" }
  );
  console.log("PSTAKE deployed: ", PSTAKEInstance.address);

  console.log("ALL DONE.");
}
