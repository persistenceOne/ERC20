const { ethers } = require("hardhat");

async function main() {

    const vestingInfos = [];

    // const listingTimestamp = 1660700000
  

    let [owner] = await ethers.getSigners();

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
      const alphaLaunchPad = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("10000000"),
        stepAmount: ethers.utils.parseEther("0"),
        numOfSteps: 0,
        stepDuration:1000,
        beneficiary: owner.address
      }
      vestingInfos.push(alphaLaunchPad);
      const airdrop = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("5000000"),
        stepAmount: ethers.utils.parseEther("5000000"),
        numOfSteps: 5,
        stepDuration: 30*24*60*60,
        beneficiary: owner.address      
      }
      vestingInfos.push(airdrop);
      const strategicSale = {
        cliffTime: listingTimestamp + 6*30*24*60*60,
        cliffAmount: ethers.utils.parseEther("8333337"),
        stepAmount: ethers.utils.parseEther("8333333"),
        numOfSteps: 11,
        stepDuration: 30*24*60*60,
        beneficiary: owner.address       
      }
      vestingInfos.push(strategicSale);
      const team = {
        cliffTime: listingTimestamp + 18*30*24*60*60,
        cliffAmount: ethers.utils.parseEther("4444452"),
        stepAmount: ethers.utils.parseEther("4444444"),
        numOfSteps: 17,
        stepDuration: 30*24*60*60,
        beneficiary: owner.address         
      }
      vestingInfos.push(team);
      const publicSale = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("6250000"),
        stepAmount: ethers.utils.parseEther("3125000"),
        numOfSteps: 6,
        stepDuration: 30*24*60*60,
        beneficiary: owner.address       
      }
      vestingInfos.push(publicSale);
      const community = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("14444448"),
        stepAmount: ethers.utils.parseEther("14444444"),
        numOfSteps: 8,
        stepDuration: 3*30*24*60*60,
        beneficiary: owner.address       
      }
      vestingInfos.push(community);
      const xprtStakers = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("1250000"),
        stepAmount: ethers.utils.parseEther("1250000"),
        numOfSteps: 11,
        stepDuration: 30*24*60*60,
        beneficiary: owner.address        
      }
      vestingInfos.push(xprtStakers);
      const treasury = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("11111112"),
        stepAmount: ethers.utils.parseEther("11111111"),
        numOfSteps: 8,
        stepDuration: 3*30*24*60*60,
        beneficiary: owner.address        
      }
      vestingInfos.push(treasury);
      const retroactive = {
        cliffTime: listingTimestamp,
        cliffAmount: ethers.utils.parseEther("10000000"),
        stepAmount: ethers.utils.parseEther("0"),
        numOfSteps: 0,
        stepDuration: 3*30*24*60*60,
        beneficiary: owner.address        
      }
      vestingInfos.push(retroactive)
    }

    prepareVestingInfoData();

    const Orchestrator = await ethers.getContractFactory('Orchestrator');


    const orchestrator = await Orchestrator.deploy(vestingInfos, owner.address)

    let tx = await orchestrator.mintAndTransferTokens();
    await tx.wait()

    console.log(`Orchestrator deployed is at ${orchestrator.address}`)
}



main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });