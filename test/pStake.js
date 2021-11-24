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
const VestingTimelockV3 = artifacts.require('VestingTimelockV3');
const PSTAKE = artifacts.require('PSTAKE');

let grantAdminAddress_ = "0xedC1434AaD72FE6eFD1C559124749cF7202C196E";
let pauseAdmin = accounts[0];

let admin = "0xedC1434AaD72FE6eFD1C559124749cF7202C196E";
let otherAddress = "0x03dc4e3B24B55932CfC099ac24276dE59A88C55B";
let zeroAddress = "0x0000000000000000000000000000000000000000"

describe('pSTAKE', () => {
    let totalAmount = new BN(1000000000000);
    let val = BigNumber("600000000000000000000000000");
    let amount = new BN(1000000);
    let inflationRate = new BN(3000000);
    let inflationRate_ = new BN(12000000000);
    let inflationPeriod = new BN(1);
    let zero = new BN(0);
    let divisor = BigNumber("1000000000000")
    let toAddress = accounts[4];
    let startTime = 1636521174;  //Wed Nov 10 2021 05:12:54 GMT+0000
    let cliffPeriod = 86400;  //1 Day
    let instalmentAmount = new BN(10000);
    let instalmentCount_ = 3;
    let installmentPeriod_ = 3600 //1 Hour
    let vestingTimelockV3;
    let pStake;


    beforeEach(async function () {
        this.project = await TestHelper()
        vestingTimelockV3 = await deployProxy(VestingTimelockV3, [pauseAdmin, grantAdminAddress_], { initializer: 'initialize' });

        pStake = await deployProxy(PSTAKE, [admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin], { initializer: 'initialize' });
       // console.log("pstake deployed: ", pStake.address)
    });

    describe("Inflation Rate", function () {

        describe("Check Inflation", function () {
            it("Malicious/illegitimate actor cannot check inflation: ", async function () {
                await expectRevert(pStake.checkInflation({from: otherAddress}), "PS13");
            });

            it("Only admin can check inflation: ", async function () {
                await pStake.checkInflation({from: admin});
            });
        })

        describe("Set Inflation", function () {
            it("Malicious/illegitimate actor cannot set inflation rate: ", async function () {
                await expectRevert(pStake.setInflation(
                    inflationRate, inflationPeriod,
                    {from: otherAddress}), "PS0");
            });

            it("Inflation rate can be 0: ", async function () {
                let set = await pStake.setInflation(zero, inflationPeriod,{from: admin});
                expectEvent(set, "SetInflationRate", {
                    inflationRate: zero,
                    inflationPeriod: inflationPeriod
                });
            });

            it("Inflation rate cannot be grater than value divisor: ", async function () {
                await expectRevert(pStake.setInflation(
                    divisor, inflationPeriod,
                    {from: admin}), "PS7");
            });

            it("Inflation period cannot be 0: ", async function () {
                await expectRevert(pStake.setInflation(
                    inflationRate_, zero,
                    {from: admin}), "PS9");
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
        })
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

        it("New supply cannot be 0", async function () {

            await expectRevert(pStake.setSupplyMaxLimit(
                zero,
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

        it("TOADDRESS cannot be 0x00", async function () {
            await expectRevert(pStake.mint(
                zeroAddress,
                amount,
                {from: admin}), "PS2");
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

    describe("Setting vesting timelock contract", function () {
        it("Only admin can set the contract address", async function () {
            await expectRevert(pStake.setVestingTimelockContract(
                vestingTimelockV3.address,
                {from: otherAddress}), "PS6");
        });

        it("Vesting timelock address cannot be 0x00", async function () {
            await expectRevert(pStake.setVestingTimelockContract(
                zeroAddress,
                {from: admin}), "PS11");
        });

        it("Set vesting timelock contract: ", async function () {

            let set =  await pStake.setVestingTimelockContract(
                vestingTimelockV3.address,
                {from: admin});

            expectEvent(set, "SetVestingTimelockContract", {
                vestingTimelockAddress: vestingTimelockV3.address
            });
            // TEST SCENARIO END
        }, 200000);
    })

    describe("Add Vesting", function () {
        it("Only admin can add vesting", async function () {
            await expectRevert(pStake.addVesting(
                otherAddress, startTime, cliffPeriod, instalmentAmount, instalmentCount_, inflationPeriod,
                {from: otherAddress}), "PS12");
        });
    })
});