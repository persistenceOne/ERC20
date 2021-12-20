/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

const VestingTimelockV3Artifact = artifacts.require("VestingTimelockV3");
var networkID;

const { BN } = web3.utils.BN;
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
var VestingTimelockV3Instance;

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
  let pauseAdmin = accounts[0];
  let grantAdmin = accounts[0];
  // let from_defaultAdmin = accounts[0];

  VestingTimelockV3Instance = await deployProxy(
    VestingTimelockV3Artifact,
    [pauseAdmin, grantAdmin],
    { deployer, initializer: "initialize" }
  );

  console.log(
    "VestingTimelockV3 deployed: ",
    VestingTimelockV3Instance.address
  );

 /* var t1 = await VestingTimelockV3Instance.addGrantAsInstalment("0xa2144FE7D53020cAe0C1B5872A71A44B327cc21f",
      "0x466aF9ea44f2dEbbE4fd54a98CffA26A3674fBf7",
      Math.round(Date.now() / 1000).toString(),
      "61", "120000000000000000000",
      "1", "120", false,
      {from:accounts[1]})*/

  console.log("ALL DONE.");
}
