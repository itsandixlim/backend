const { ethers } = require("hardhat");

async function deployTicketContract() {
  const [owner] = await ethers.getSigners();

  const TicketContract = await ethers.getContractFactory("Ticket");
  const ticketContract = await TicketContract.deploy(10, 5, 2); // creationFeePercentage, purchaseFeePercentage, resellingFeePercentage

  await ticketContract.deployed();

  console.log("Ticket contract deployed to:", ticketContract.address);
  console.log("Owner:", owner.address);
}

deployTicketContract()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });