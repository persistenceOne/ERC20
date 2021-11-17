//UNIT TEST

/* This unit test uses the OpenZeppelin test environment and OpenZeppelin test helpers,
which we will be using for our unit testing. */
const {web3} = require("@openzeppelin/test-helpers/src/setup");
const {
    deployProxy,
} = require("@openzeppelin/truffle-upgrades");

const {
    accounts,
    contract,
} = require("@openzeppelin/test-environment");
const {
    BN,
    expectEvent,
    expectRevert,
} = require("@openzeppelin/test-helpers");
const { TestHelper } = require('zos');
const { ZWeb3 } = require('zos-lib');
const BigNumber = require('big-number');

ZWeb3.initialize(web3.currentProvider);
const VestingTimelockV2 = artifacts.require('VestingTimelockV2');
const PSTAKE = artifacts.require('PSTAKE');

let grantAdminAddress_ = "0x811F34E9Ad663a3E56A2deFAE73EA81eE89a80E6";
let pauseAdmin = accounts[0];

let admin = "0x811F34E9Ad663a3E56A2deFAE73EA81eE89a80E6";
let otherAddress = "0xB0931cd7801F94DDfEa514b4E4A06c94Fa656BFb";

describe('pSTAKE', () => {
    let totalAmount = new BN(1000000000000);
    let val = BigNumber("600000000000000000000000000");
    let amount = new BN(1000000);
    let inflationRate = new BN(3000000);
    let inflationRate_ = new BN(12000000000);
    let inflationPeriod = new BN(1);
    let toAddress = accounts[4];
    let vestingTimelockV2;
    let pStake;


    beforeEach(async function () {
        this.project = await TestHelper()
        vestingTimelockV2 = await deployProxy(VestingTimelockV2, [pauseAdmin, grantAdminAddress_], { initializer: 'initialize' });

        pStake = await deployProxy(PSTAKE, [admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin], { initializer: 'initialize' });
       // console.log("pstake deployed: ", pStake.address)
    });

    describe("Inflation Rate", function () {
        it("Malicious/illegitimate actor cannot set inflation rate: ", async function () {
            await expectRevert(pStake.setInflation(
                inflationRate, inflationPeriod,
                {from: otherAddress}), "PS0");
        });

        it("Inflation rate to be not more than 100: ", async function () {
            await expectRevert(pStake.setInflation(
                inflationRate_, inflationPeriod,
                {from: admin}), "PS7");
        });

        it("Set inflation rate: ", async function () {

            let set =  await pStake.setInflation(
                inflationRate, inflationPeriod,
                {from: admin});

            expectEvent(set, "SetInflationRate", {
                inflationRate: inflationRate,
                inflationPeriod: inflationPeriod
            });
            // TEST SCENARIO END
        }, 200000);
    });

    describe("Set Supply Max Limit", function () {

        it("Only admin can set supply max limit", async function () {

            await expectRevert(pStake.setSupplyMaxLimit(
                totalAmount,
                {from: otherAddress}), "PS8");
        });

        it("New supply max limit cannot be less than totalInflatedSupply", async function () {

            await expectRevert(pStake.setSupplyMaxLimit(
                totalAmount,
                {from: admin}), "PS10");
        });

        it("Set supply max limit", async function () {

            let set =  await pStake.setSupplyMaxLimit(
                val,
                {from: admin});

            expectEvent(set, "SetSupplyMaxLimit", {
                supplyMaxLimit: val.toString()
            });
        });
    });

    describe("Mint", function () {
        it("Only admin can mint tokens", async function () {
            await expectRevert(pStake.mint(
                toAddress,
                amount,
                {from: otherAddress}), "PS1");
        });

        it("Mint", async function () {
            let set =  await pStake.setInflation(
                inflationRate, inflationPeriod,
                {from: admin});

            expectEvent(set, "SetInflationRate", {
                inflationRate: inflationRate,
                inflationPeriod: inflationPeriod
            });

            let mint = await pStake.mint(
                toAddress,
                amount,
                {from: admin});
            expectEvent(mint, "Transfer", {
                to: toAddress
            });
        });
    });
});