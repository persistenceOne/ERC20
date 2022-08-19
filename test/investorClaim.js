/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

const {expect} = require("chai");
const {ethers, network} = require("hardhat");

const rpcCall = async (callType, params) => {
    return await network.provider.request({
        method: callType,
        params: params,
    });
};

const snapshot = async () => {
    return await rpcCall("evm_snapshot", []);
};

const revertToSnapshot = async (snapId) => {
    return await rpcCall("evm_revert", [snapId]);
};

const increaseTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds])
    await network.provider.send("evm_mine")
}
const setTime = async (time) => {
    await network.provider.send("evm_setNextBlockTimestamp", [time])
    await network.provider.send("evm_mine")
}

describe("InvestorClaim", function () {

    // let owner, account1, account2, account3, account4, account5, account6, account7, account8;
    let admin, investor_account1, investor_account2, investor_account3, investor_account4;
    let snapshotId;
    const vestingInfos = [];

    const listingTimestamp = 1660700000


    before(async function () {
        [admin, investor_account1, investor_account2, investor_account3, investor_account4] = await ethers.getSigners();

        const Investor = await ethers.getContractFactory("InvestorClaim");
        const pstake = await ethers.getContractFactory("testPstake");
        this.pstake = await pstake.deploy();

        console.log("deployed pstake token:", this.pstake.address);
        const investorAmount = [[investor_account1.address, BigInt(600000e18)], [investor_account2.address, BigInt(360000e18)], [investor_account3.address, BigInt(120000e18)]]
        this.investor = await Investor.deploy(admin.address, this.pstake.address, investorAmount)
        console.log("investor claim contract deployed to:", this.investor.address)
    })

    beforeEach(async function () {
        snapshotId = await snapshot();
    });

    afterEach(async function () {
        await revertToSnapshot(snapshotId);
    });

    describe("admin actions", function () {
        it("adds money to contract", async function () {
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(750000e18));
            await this.investor.connect(admin).addMoney(BigInt(750000e18));
            await expect(BigInt(await this.pstake.balanceOf(this.investor.address))).to.equal(BigInt(750000e18));
        });
        it("does not add money to contract", async function () {

            await this.pstake.connect(admin).approve(this.investor.address, BigInt(800e18));
            await expect(this.investor.connect(admin).addMoney(BigInt(800e18))).to.be.revertedWith('AmountLessThanTotalInvestorAmount');
        });
        it("does not add money to contract", async function () {

            await this.pstake.connect(admin).transfer(investor_account4.address, BigInt(1000e18));
            await this.pstake.connect(investor_account4).approve(this.investor.address, BigInt(800e18))
            await expect(this.investor.connect(investor_account4).addMoney(BigInt(800e18))).to.be.revertedWith('NotAdmin');
        });
        it("withdraw remaining money", async function () {
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(750000e18));
            await this.investor.connect(admin).addMoney(BigInt(750000e18));
            await expect(BigInt(await this.pstake.balanceOf(this.investor.address))).to.equal(BigInt(750000e18));
            await this.investor.connect(investor_account1).claim();
            await this.investor.connect(investor_account2).claim();
            await expect(this.investor.connect(admin).returnAmountLeft()).to.be.revertedWith('TokenLeftToClaim');
            await this.investor.connect(investor_account3).claim();
            await this.investor.connect(admin).returnAmountLeft();
        });
    })
    describe("investors action", function () {
        it("can claim money", async function () {
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(900000e18));
            await this.investor.connect(admin).addMoney(BigInt(900000e18));
            await this.investor.connect(investor_account1).claim();
            await this.investor.connect(investor_account3).claim();
            let amount = BigInt(await this.investor.connect(investor_account2).tokensLeft());
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(900000e18));
            await this.investor.connect(admin).addMoney(BigInt(900000e18));
            await expect(BigInt(await this.investor.connect(investor_account2).tokensLeft())).to.equal(BigInt(2)*amount);
        });
        it("already claimed money", async function () {
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(700000e18));
            await this.investor.connect(admin).addMoney(BigInt(700000e18));
            await this.investor.connect(investor_account1).claim();
            await this.investor.connect(investor_account2).claim();
            await this.investor.connect(investor_account3).claim();
            await expect(this.investor.connect(investor_account1).claim()).to.be.revertedWith('AlreadyClaimed');
            await expect(this.investor.connect(investor_account2).claim()).to.be.revertedWith('AlreadyClaimed');
            await expect(this.investor.connect(investor_account3).claim()).to.be.revertedWith('AlreadyClaimed');
        });
        it("not a investor", async function () {
            await this.pstake.connect(admin).approve(this.investor.address, BigInt(600000e18));
            await this.investor.connect(admin).addMoney(BigInt(600000e18));
            await this.investor.connect(investor_account1).claim();
            await expect(this.investor.connect(investor_account4).claim()).to.be.revertedWith("NotInvestor");
        });
        it("12 installments passed", async function () {
            for (let i = 0; i < 12; i++) {
                await this.pstake.connect(admin).approve(this.investor.address, BigInt(900000e18));
                await this.investor.connect(admin).addMoney(BigInt(900000e18));
                await this.investor.connect(investor_account1).claim();
                await this.investor.connect(investor_account2).claim();
                await this.investor.connect(investor_account3).claim();
            }
            console.log("balance admin:",BigInt(await this.pstake.balanceOf(admin.address)));
            console.log("total claimed by investor1:", BigInt(await this.investor.connect(investor_account1).claimedTokens()));
            console.log("total claimed by investor2:", BigInt(await this.investor.connect(investor_account2).claimedTokens()));
            console.log("total claimed by investor3:", BigInt(await this.investor.connect(investor_account3).claimedTokens()));
            await this.investor.connect(investor_account4).returnAmountLeft();
            console.log("balance admin:",BigInt(await this.pstake.balanceOf(admin.address)));
        })

    })

});

