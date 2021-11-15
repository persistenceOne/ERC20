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
const { Contracts, ZWeb3 } = require('zos-lib');

ZWeb3.initialize(web3.currentProvider);
const VestingTimelockV2 = artifacts.require('VestingTimelockV2');
const PSTAKE = artifacts.require('PSTAKE');

let grantAdminAddress_ = "0xC03A2dD82F036dC5140815604c0f169ED4e97E0f";
let pauseAdmin = accounts[0];

let beneficiaryAddress = accounts[1];
let admin = "0xC03A2dD82F036dC5140815604c0f169ED4e97E0f";
let otherAddress = "0xDdB6f64c001d45FAA9Df3F16099370B28678A19E";

describe('Vesting Timelock', () => {
    let startTime = 1636521174;  //Wed Nov 10 2021 05:12:54 GMT+0000
    let cliffPeriod = 86400;  //1 Day
    let totalAmount = new BN(1000000000000);
    let amount = new BN(100000);
    let instalmentAmount = new BN(10000);
    let instalmentCount_ = 3;
    let installmentPeriod_ = 3600 //1 Hour
    let vestingTimelockV2;
    let pStake;


    beforeEach(async function () {
        this.project = await TestHelper()
        vestingTimelockV2 = await deployProxy(VestingTimelockV2, [pauseAdmin, grantAdminAddress_], { initializer: 'initialize' });

        pStake = await deployProxy(PSTAKE, [admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin], { initializer: 'initialize' });
       // console.log("pstake deployed: ", pStake.address)
    });

    describe("Add Grant", function () {
        it("Malicious/illegitimate actor cannot add grants: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                "0x",
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "invalid address");
        });

        it("Number of instalmentAmount should be greater than 0/balance: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, amount, {from: admin});

            await expectRevert(vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                totalAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "transfer amount exceeds allowance");
        });

        it("Add Grant: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin});

            expectEvent(add, "AddGrant", {
                instalmentAmount: instalmentAmount
            });
            // TEST SCENARIO END
        }, 200000);

        it("Check if an existing active grant is not already in effect: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin});

            expectEvent(add, "AddGrant", {
                instalmentAmount: instalmentAmount
            });

            await expectRevert(vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT17");
            // TEST SCENARIO END
        }, 200000);
    });

    describe("Revoke Grant", function () {

        it("Get the ID and retrieve grantManager to compare with the msgSender ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, amount, {from: admin});

            let add =  await vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin});

            expectEvent(add, "AddGrant", {
                instalmentAmount: instalmentAmount
            });

            await expectRevert(vestingTimelockV2.revokeGrant(
                pstakeTokenAddress,
                otherAddress,
                {from: otherAddress}), "VT7");
        });

        it("Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, amount, {from: admin});

            let add =  await vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin});

            expectEvent(add, "AddGrant", {
                instalmentAmount: instalmentAmount
            });

            await expectRevert(vestingTimelockV2.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: otherAddress}), "VT6");
        });

        it("Revoke Grant: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV2.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV2.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin});

            expectEvent(add, "AddGrant", {
                instalmentAmount: instalmentAmount
            });

            let revoke =  await vestingTimelockV2.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_});

            expectEvent(revoke, "RevokeGrant", {
                tokens: instalmentAmount.mul(new BN(instalmentCount_))
            });
            // TEST SCENARIO END
        }, 200000);
    });
});