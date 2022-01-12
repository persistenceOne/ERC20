/*
 Copyright [2019] - [2021], PERSISTENCE TECHNOLOGIES PTE. LTD. and the ERC20 contributors
 SPDX-License-Identifier: Apache-2.0
*/

const { ethers } = require("hardhat");

async function main() {

    const vestingInfos = [];
    let accounts = []

    let getAddresses = await ethers.getSigners();
    for (const account of getAddresses) {
        accounts.push(account.address)
    }

    const listingTimestamp = 1644246000; //Feb 07 2022 15:00:00 UTC/GMT
    //const listingTimestamp = 1633102368; //1st oct 2021, 15:00:00 UTC/GMT
    let owner = accounts[0];
    let minter = accounts[1];
    let airdropAdmin = "0x97Ef7Eda907A3DFe498fBFfF14E95716F2efFFa2";
    let alphaLaunchPadAdmin = "0x657DF56C50024Ae31c4ACf0d82Ba86930bE3539a";
    let strategicSaleAdmin = "0xb816aaf0821de061300485E2342babF654867c2E";
    let teamAdmin = "0x787fE98ed28Ec34b1aeCE72CFee439C5dA629907";
    let publicSaleAdmin = "0x882cb571Fd49ec8E27D228f5D1C3c74901Ff866B";
    let communityAdmin = "0x0552A5bdEAe697320b8b0F5FA94946DC6dd9dFf4";
    let xprtStakersAdmin = "0x80b4B32eD4b1b14e9161915c2Bebf91bc00A5032";
    let treasuryAdmin = "0xF55E5A4Bb2Fe60de947ccE5DDCbb1b39E0AB7Ba3";
    let retroactiveAdmin = "0xeB488BAe77c45629224993e9563928c42D87492C";

//     //1640606872
    function prepareVestingInfoData(){
  
  /**
          address beneficiary;
          uint256 cliffTime;
          uint256 stepAmount;
          uint256 cliffAmount;
          uint256 stepDuration;
          uint256 numOfSteps; 
   */
      const airdrop = {
          cliffTime: listingTimestamp,
          cliffAmount: ethers.utils.parseEther("5000000"),
          stepAmount: ethers.utils.parseEther("5000000"),
          numOfSteps: 5,
          stepDuration: 30*24*60*60,
          beneficiary: airdropAdmin
      }
      vestingInfos.push(airdrop);

      const alphaLaunchPad = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("10000000"),
        stepAmount: ethers.utils.parseEther("0"),
        numOfSteps: 0,
        stepDuration:1000,
        beneficiary: alphaLaunchPadAdmin
      }
      vestingInfos.push(alphaLaunchPad);

      const strategicSale = {
        cliffTime: listingTimestamp + 6*30*24*60*60,
        cliffAmount: ethers.utils.parseEther("8333337"),
        stepAmount: ethers.utils.parseEther("8333333"),
        numOfSteps: 11,
        stepDuration: 30*24*60*60,
        beneficiary: strategicSaleAdmin
      }
      vestingInfos.push(strategicSale);

      const team = {
        cliffTime: listingTimestamp + 18*30*24*60*60,
        cliffAmount: ethers.utils.parseEther("4444452"),
        stepAmount: ethers.utils.parseEther("4444444"),
        numOfSteps: 17,
        stepDuration: 30*24*60*60,
        beneficiary: teamAdmin
      }
      vestingInfos.push(team);

      const publicSale = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("6250000"),
        stepAmount: ethers.utils.parseEther("3125000"),
        numOfSteps: 6,
        stepDuration: 30*24*60*60,
        beneficiary: publicSaleAdmin
      }
      vestingInfos.push(publicSale);

      const community = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("14444448"),
        stepAmount: ethers.utils.parseEther("14444444"),
        numOfSteps: 8,
        stepDuration: 3*30*24*60*60,
        beneficiary: communityAdmin
      }
      vestingInfos.push(community);

      const xprtStakers = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("1250000"),
        stepAmount: ethers.utils.parseEther("1250000"),
        numOfSteps: 11,
        stepDuration: 30*24*60*60,
        beneficiary: xprtStakersAdmin
      }
      vestingInfos.push(xprtStakers);

      const treasury = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("11111112"),
        stepAmount: ethers.utils.parseEther("11111111"),
        numOfSteps: 8,
        stepDuration: 3*30*24*60*60,
        beneficiary: treasuryAdmin
      }
      vestingInfos.push(treasury);

      const retroactive = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("10000000"),
        stepAmount: ethers.utils.parseEther("0"),
        numOfSteps: 0,
        stepDuration: 3*30*24*60*60,
        beneficiary: retroactiveAdmin
      }
      vestingInfos.push(retroactive)
    }

    prepareVestingInfoData();

    console.log("Starting the deployment......")

    const Orchestrator = await ethers.getContractFactory('Orchestrator');

    const orchestrator = await Orchestrator.deploy(vestingInfos, minter)

    let tx = await orchestrator.mintAndTransferTokens();
    await tx.wait()

   let tokenAddress = await orchestrator.token();

    console.log("pStake token contract address: ", tokenAddress)

    console.log(`Orchestrator deployed is at ${orchestrator.address}`)
}



main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });