
const hre = require("hardhat");
async function main() {
  let LootBox;
  let ItemContract;
  let KeyContract;
  
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  LootBox = await hre.ethers.getContractFactory("LootBoxContract");
  ItemContract = await hre.ethers.getContractFactory("ItemsContract");
  KeyContract = await hre.ethers.getContractFactory("KeyContract");

  LootBox = await LootBox.deploy("lootBox","LOOT", deployer.address,"https://test/");
  await LootBox.waitForDeployment();
  console.log("LootBox Address: ", LootBox.target);

  ItemContract = await ItemContract.deploy("itemContract", "ITEM","https://test/");
  await ItemContract.waitForDeployment();
  console.log("ItemContract Address: ", ItemContract.target);

  KeyContract = await KeyContract.deploy("KeyContract", "KEY", LootBox.target,"https://test/");
  await KeyContract.waitForDeployment();
  console.log("KeyContract Address: ", KeyContract.target);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
