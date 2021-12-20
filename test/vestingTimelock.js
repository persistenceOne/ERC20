/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

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
const VestingTimelockV3 = artifacts.require('VestingTimelockV3');
const PSTAKE = artifacts.require('PSTAKE');

let grantAdminAddress_ = "0xedC1434AaD72FE6eFD1C559124749cF7202C196E";
let pauseAdmin = accounts[0];

let beneficiaryAddress = accounts[1];
let admin = "0xedC1434AaD72FE6eFD1C559124749cF7202C196E";
let otherAddress = "0x03dc4e3B24B55932CfC099ac24276dE59A88C55B";
let zeroAddress = "0x0000000000000000000000000000000000000000"

describe('Vesting Timelock', () => {
    let startTime = 1636521174;  //Wed Nov 10 2021 05:12:54 GMT+0000
    let cliffPeriod = 86400;  //1 Day
    let _cliffPeriod = 315600000 //10 years
    let totalAmount = new BN(1000000000000);
    let zeroAmount = new BN(0);
    let amount = new BN(100000);
    let instalmentAmount = new BN(10000);
    let instalmentCount_ = 3;
    let _instalmentCount = 1201;
    let installmentPeriod_ = 3600 //1 Hour
    let vestingTimelockV3;
    let pStake;


    beforeEach(async function () {
        this.project = await TestHelper()
        vestingTimelockV3 = await deployProxy(VestingTimelockV3, [pauseAdmin, grantAdminAddress_], { initializer: 'initialize' });

        pStake = await deployProxy(PSTAKE, [admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin,admin], { initializer: 'initialize' });
       // console.log("pstake deployed: ", pStake.address)
    });

    describe("Add Grant", function () {

        it("pstakeTokenAddress cannot be 0x00: ", async function () {

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                zeroAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Beneficiary address cannot be 0x00: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                zeroAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Cliff Period cannot be greater than 10 years: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                _cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Start time cannot be greater than 10 years: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                _cliffPeriod,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Installment amount cannot be 0: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                zeroAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Installment count cannot be 0: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                zeroAddress,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Installment count cannot be greater than 1200: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                _instalmentCount,
                installmentPeriod_,
                {from: admin}), "VT3");
        });

        it("Installment period cannot be greater than 10 years: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                _cliffPeriod,
                {from: admin}), "VT3");
        });

        it("Installment period cannot be greater than 10 years: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                instalmentAmount,
                instalmentCount_,
                zeroAmount,
                {from: admin}), "VT18");
        });


        it("token is some random address: ", async function () {

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                otherAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                totalAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "revert");
        });

        it("Number of instalmentAmount should be greater than 0/balance: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                totalAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: admin}), "transfer amount exceeds allowance");
        });

        it("Grant Manager dont have enough balance: ", async function () {

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            await expectRevert(vestingTimelockV3.addGrant(
                pStake.address,
                beneficiaryAddress,
                startTime,
                cliffPeriod,
                totalAmount,
                instalmentCount_,
                installmentPeriod_,
                {from: otherAddress}), "VT11");
        });

        it("Check if an existing active grant is not already in effect: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.addGrant(
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

        it("Add Grant --> Revoke Grant --> Add Grant: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            let revoke =  await vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_});

            expectEvent(revoke, "RevokeGrant", {
                tokens: instalmentAmount.mul(new BN(instalmentCount_))
            });

            add =  await vestingTimelockV3.addGrant(
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
    });

    describe("Revoke Grant", function () {

        it("Token address cannot be 0x00 ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.revokeGrant(
                zeroAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "VT5");
        });

        it("Beneficiary address cannot be 0x00 ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                zeroAddress,
                {from: grantAdminAddress_}), "VT5");
        });

        it("Grant can be revoked by the beneficiary, grant manager or GRANT ADMIN: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: otherAddress}), "VT6");
        });

        it("Token address is a random address: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.revokeGrant(
                otherAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "revert");
        });

        it("No active grants to revoke: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            await expectRevert(vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "revert");
        });

        it("Revoke Grant: ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, totalAmount,{from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            let revoke =  await vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_});

            expectEvent(revoke, "RevokeGrant", {
                tokens: instalmentAmount.mul(new BN(instalmentCount_))
            });
            // TEST SCENARIO END
        }, 200000);

        it("Add Grant --> Revoke Grant --> Revoke Grant ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            let revoke =  await vestingTimelockV3.revokeGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_});

            expectEvent(revoke, "RevokeGrant", {
                tokens: instalmentAmount.mul(new BN(instalmentCount_))
            });

            await expectRevert(vestingTimelockV3.revokeGrant(
                otherAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "revert");
        });
    });

    describe("Claim Grant", function () {

        it("Token address cannot be 0x00 ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.claimGrant(
                zeroAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "VT8");
        });

        it("Beneficiary address cannot be 0x00 ", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.claimGrant(
                pstakeTokenAddress,
                zeroAddress,
                {from: grantAdminAddress_}), "VT8");
        });

        it("Sender should have role granted for claim", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.claimGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: otherAddress}), "VT10");
        });

        it("Token address is a random address", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            await expectRevert(vestingTimelockV3.claimGrant(
                otherAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "revert");
        });

        it("There are no active grants", async function () {
            let pstakeTokenAddress = pStake.address;

            await expectRevert(vestingTimelockV3.claimGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_}), "VT12");
        });

        it("Claim Grant", async function () {
            let pstakeTokenAddress = pStake.address;

            await pStake.approve(vestingTimelockV3.address, amount, {from: admin});

            let add =  await vestingTimelockV3.addGrant(
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

            let claim = await vestingTimelockV3.claimGrant(
                pstakeTokenAddress,
                beneficiaryAddress,
                {from: grantAdminAddress_});

            expectEvent(claim, "ClaimGrant", {
                token: pstakeTokenAddress,
                accountAddress: beneficiaryAddress
            });
        });
    })
});