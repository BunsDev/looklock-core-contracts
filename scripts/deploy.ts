import { ethers } from "hardhat";

async function main() {
  const Lolo = await ethers.getContractFactory("Lolo");
  const lolo = await Lolo.deploy(10000000);

  await lolo.deployed();

  console.log("Lolo deployed to:", lolo.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
