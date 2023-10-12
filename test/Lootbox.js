const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");

describe("Lootbox Test", function () {
  let LootBox;
  let ItemContract;
  let KeyContract;
  let owner;
  let addr1;
  let addr2;
  let addr3;

  beforeEach(async function () {
    LootBox = await ethers.getContractFactory("LootBoxContract");
    ItemContract = await ethers.getContractFactory("ItemsContract");
    KeyContract = await ethers.getContractFactory("KeyContract");
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    LootBox = await LootBox.deploy("lootBox","LOOT", owner.address,"https://test/");
    await LootBox.waitForDeployment();

    ItemContract = await ItemContract.deploy("itemContract", "ITEM","https://test/");
    await ItemContract.waitForDeployment();

    KeyContract = await KeyContract.deploy("KeyContract", "KEY", LootBox.target,"https://test/");
    await KeyContract.waitForDeployment();
    
  });

  it("Add keyContract address to Lootbox contract", async function () {
    await LootBox.addKeyContract(KeyContract.target);
    expect(await LootBox.keyContract()).to.equal(KeyContract.target);
  });

  it("Set Lootbox contract as Minter in itemContract", async function () {
    await ItemContract.grantMinterRole(LootBox.target);
    expect(await ItemContract.isMinter(LootBox.target)).to.equal(true);
  });
  
  it("Create an item in itemContract", async function () {
    await ItemContract.addItem("test");
    const checkItem = await ItemContract.items(1);
    expect(checkItem[1]).to.equal("test");
  });

  it("Create an Lootbox", async function () {
    await ItemContract.addItem("test");
    await ItemContract.addItem("test1");

    await ItemContract.grantMinterRole(LootBox.target);
    await LootBox.addKeyContract(KeyContract.target);

    await LootBox.createLootBox(
        1000, 
        ItemContract.target,
        1, 
        [1,2],
        [20,80]
    );
    
    const checkLootbox = await LootBox.lootBoxes(1);
    expect(checkLootbox[1]).to.equal(1000); //check if the lootbox with id 1 is there and if the supply is 1000
  });

  it("Change an key price", async function () {
    await ItemContract.addItem("test");
    await ItemContract.addItem("test1");

    await ItemContract.grantMinterRole(LootBox.target);
    await LootBox.addKeyContract(KeyContract.target);

    await LootBox.createLootBox(
        1000, 
        ItemContract.target,
        1, 
        [1,2],
        [20,80]
    );

    await KeyContract.changeKeyPrice(1,1111);
    const checkKeyPrice = await KeyContract.keyInfos(1);
    expect(checkKeyPrice[1]).to.equal(1111);
  });


  it("Buy An key", async function () {
    await ItemContract.addItem("test");
    await ItemContract.addItem("test1");

    await ItemContract.grantMinterRole(LootBox.target);
    await LootBox.addKeyContract(KeyContract.target);

    await LootBox.createLootBox(
        1000, 
        ItemContract.target,
        1, 
        [1,2],
        [20,80]
    );

    
    const options = { value: 1 };
    await KeyContract.purchaseKey(1,1, options);
    expect(await KeyContract.balanceOf(owner.address)).to.equal(1);
  });

  it("Drop user an LootBox", async function () {
    await ItemContract.addItem("test");
    await ItemContract.addItem("test1");

    await ItemContract.grantMinterRole(LootBox.target);
    await LootBox.addKeyContract(KeyContract.target);

    await LootBox.createLootBox(
        1000, 
        ItemContract.target,
        1, 
        [1,2],
        [20,80]
    );

    
    await LootBox.mintLootBox(owner.address, 1);
    
    expect(await LootBox.balanceOf(owner.address)).to.equal(1);
  });

  it("Open an LootBox and get item", async function () {
    await ItemContract.addItem("test");
    await ItemContract.addItem("test1");

    await ItemContract.grantMinterRole(LootBox.target);
    await LootBox.addKeyContract(KeyContract.target);

    await LootBox.createLootBox(
        1000, 
        ItemContract.target,
        1, 
        [1,2],
        [20,80]
    );
    await LootBox.mintLootBox(owner.address, 1);
    const options = { value: 1 };
    await KeyContract.purchaseKey(1,1, options);
    await LootBox.openBox(0,0);

    expect(await LootBox.balanceOf(owner.address)).to.equal(0);
    expect(await KeyContract.balanceOf(owner.address)).to.equal(0);
    expect(await ItemContract.balanceOf(owner.address)).to.equal(1);
  });

});

