const { expect } = require("chai");
const { ethers, network } = require("hardhat");

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

describe("StepVesting", function () {

  let owner, account1, account2, account3, account4, account5, account6, account7, account8;
  let snapshotId;
  const vestingInfos = [];

  const listingTimestamp = 1660700000

  //1640606872
  function prepareVestingInfoData(){

/**
        address beneficiary;
        uint256 cliffTime;
        uint256 stepAmount;
        uint256 cliffAmount;
        uint256 stepDuration;
        uint256 numOfSteps; 
 */
    const alphaLaunchPad = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("10000000"),
      stepAmount: ethers.utils.parseEther("0"),
      numOfSteps: 0,
      stepDuration:1000,
      beneficiary: account1.address
    }
    vestingInfos.push(alphaLaunchPad);
    const airdrop = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("5000000"),
      stepAmount: ethers.utils.parseEther("5000000"),
      numOfSteps: 5,
      stepDuration: 30*24*60*60,
      beneficiary: account2.address      
    }
    vestingInfos.push(airdrop);
    const strategicSale = {
      cliffTime: listingTimestamp + 6*30*24*60*60,
      cliffAmount: ethers.utils.parseEther("8333337"),
      stepAmount: ethers.utils.parseEther("8333333"),
      numOfSteps: 11,
      stepDuration: 30*24*60*60,
      beneficiary: account3.address       
    }
    vestingInfos.push(strategicSale);
    const team = {
      cliffTime: listingTimestamp + 18*30*24*60*60,
      cliffAmount: ethers.utils.parseEther("4444452"),
      stepAmount: ethers.utils.parseEther("4444444"),
      numOfSteps: 17,
      stepDuration: 30*24*60*60,
      beneficiary: account4.address         
    }
    vestingInfos.push(team);
    const publicSale = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("6250000"),
      stepAmount: ethers.utils.parseEther("3125000"),
      numOfSteps: 6,
      stepDuration: 30*24*60*60,
      beneficiary: account5.address       
    }
    vestingInfos.push(publicSale);
    const community = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("14444448"),
      stepAmount: ethers.utils.parseEther("14444444"),
      numOfSteps: 8,
      stepDuration: 3*30*24*60*60,
      beneficiary: account6.address       
    }
    vestingInfos.push(community);
    const xprtStakers = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("1250000"),
      stepAmount: ethers.utils.parseEther("1250000"),
      numOfSteps: 11,
      stepDuration: 30*24*60*60,
      beneficiary: account7.address        
    }
    vestingInfos.push(xprtStakers);
    const treasury = {
      cliffTime: listingTimestamp,
      cliffAmount: ethers.utils.parseEther("11111112"),
      stepAmount: ethers.utils.parseEther("11111111"),
      numOfSteps: 8,
      stepDuration: 3*30*24*60*60,
      beneficiary: account8.address        
    }
    vestingInfos.push(treasury);
  }

  before ( async function() {
    [owner, account1, account2, account3, account4, account5, account6, account7, account8] = await ethers.getSigners();
    prepareVestingInfoData();

    const Orchestrator = await ethers.getContractFactory("Orchestrator");

    this.orchestrator = await Orchestrator.deploy(vestingInfos, owner.address);

    await this.orchestrator.mintAndTransferTokens();
    let pstakeAddress = await this.orchestrator.token();
    this.pstake = await ethers.getContractAt('pStake', pstakeAddress);
  })

  beforeEach(async function () {
    snapshotId = await snapshot();
  });

  afterEach(async function () {
    await revertToSnapshot(snapshotId);
  });


  it("should transfer correct amount of tokens to vesting contract", async function () {
    let vestingInfo = vestingInfos[0];
    let vesting = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let balance = await this.pstake.balanceOf(vesting);

    expect(balance).to.equal(vestingInfo.cliffAmount.add(vestingInfo.stepAmount.mul(vestingInfo.numOfSteps)));
  });


  it("should claim cliffAmount tokens on cliff", async function() {

    await setTime(listingTimestamp);

    let vestingInfo = vestingInfos[0];
    let vestingAddress = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let vesting = await ethers.getContractAt('StepVesting', vestingAddress);
    
    await vesting.connect(account1).claim();
    let balance = await this.pstake.balanceOf(account1.address);

    expect(balance).to.equal(vestingInfo.cliffAmount);

  })

  it("should claim zero before cliff", async function() {

    await setTime(listingTimestamp-2);

    let vestingInfo = vestingInfos[0];
    let vestingAddress = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let vesting = await ethers.getContractAt('StepVesting', vestingAddress);
    
    await vesting.connect(account1).claim();
    let balance = await this.pstake.balanceOf(account1.address);

    expect(balance).to.equal(0);

  })

  it("should only be claimable by beneficiary", async function() {

    await setTime(listingTimestamp);

    let vestingInfo = vestingInfos[0];
    let vestingAddress = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let vesting = await ethers.getContractAt('StepVesting', vestingAddress);
    
    await expect(vesting.connect(account2).claim()).to.be.revertedWith("access denied");
    await vesting.connect(account1).claim();
    let balance = await this.pstake.balanceOf(account1.address);

    expect(balance).to.equal(vestingInfo.cliffAmount);

  })

  it("should be claimed after step duration correctly", async function() {

    await setTime(listingTimestamp);

    let vestingInfo = vestingInfos[1];
    let vestingAddress = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let vesting = await ethers.getContractAt('StepVesting', vestingAddress);
    
    await vesting.connect(account2).claim();
    let preBalance = await this.pstake.balanceOf(account2.address);

    expect(preBalance).to.equal(vestingInfo.cliffAmount);

    await setTime(listingTimestamp + vestingInfo.stepDuration);

    await vesting.connect(account2).claim();

    let diffAmount = (await this.pstake.balanceOf(account2.address)).sub(preBalance);

    expect(diffAmount).to.equal(vestingInfo.stepAmount);

  })

  it("shouldn't be claimed before step duration", async function() {

    await setTime(listingTimestamp);

    let vestingInfo = vestingInfos[1];
    let vestingAddress = await this.orchestrator.vestingMapping(vestingInfo.beneficiary);

    let vesting = await ethers.getContractAt('StepVesting', vestingAddress);
    
    await vesting.connect(account2).claim();
    let preBalance = await this.pstake.balanceOf(account2.address);

    expect(preBalance).to.equal(vestingInfo.cliffAmount);

    await setTime(listingTimestamp + vestingInfo.stepDuration - 2);

    await vesting.connect(account2).claim();

    let diffAmount = (await this.pstake.balanceOf(account2.address)).sub(preBalance);

    expect(diffAmount).to.equal(0);

  })


});
