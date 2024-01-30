// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const ERC20Token_GTT = await ethers.getContractFactory("ERC20Token_GTT");
  // const GTT = await ERC20Token_GTT.deploy();
  // await GTT.waitForDeployment();
  // const ERC20Token_GTTAddr = GTT.target;
  // console.log("ERC20Token_GTT contract has been deployed to: " + ERC20Token_GTTAddr);

  // const ERC777Token_GTST = await ethers.getContractFactory("ERC777Token_GTST");
  // const GTST = await ERC777Token_GTST.deploy();
  // await GTST.waitForDeployment();
  // const ERC777Token_GTSTAddr = GTST.target;
  // console.log("ERC777Token_GTST contract has been deployed to: " + ERC777Token_GTSTAddr);

  // const FairTokenGFTContract = await ethers.getContractFactory("FairTokenGFT");
  // const GFT = await FairTokenGFTContract.deploy();
  // await GFT.waitForDeployment();
  // const FairTokenGFTAddr = GFT.target;
  // console.log("FairTokenGFT contract has been deployed to: " + FairTokenGFTAddr);

  // const ERC721TokenWithPermit_V2Contract = await ethers.getContractFactory("ERC721TokenWithPermit_V2");
  // const ERC721TokenWithPermit_V2 = await ERC721TokenWithPermit_V2Contract.deploy();
  // await ERC721TokenWithPermit_V2.waitForDeployment();
  // const ERC721TokenWithPermit_V2Addr = ERC721TokenWithPermit_V2.target;
  // console.log("ERC721TokenWithPermit_V2 contract has been deployed to: " + ERC721TokenWithPermit_V2Addr);

  // const SuperBankContract = await ethers.getContractFactory("SuperBank");
  // const SuperBank = await SuperBankContract.deploy();
  // await SuperBank.waitForDeployment();
  // const SuperBankAddr = SuperBank.target;
  // console.log("SuperBank contract has been deployed to: " + SuperBankAddr);

  // Upgradable Deployment:
  const ERC777Token_GTSTAddr = "0x94B1424C3435757E611F27543eedB37bcD3BDEb4";
  const NFTMarket_V2_2Contract = await ethers.getContractFactory("NFTMarket_V2_2");
  const NFTMarket_V2_2 = await upgrades.deployProxy(NFTMarket_V2_2Contract, [ERC777Token_GTSTAddr], { initializer: "init(address)" });
  await NFTMarket_V2_2.waitForDeployment();
  const NFTMarket_V2_2Addr = NFTMarket_V2_2.target;
  console.log("NFTMarket_V2_2 contract has been deployed to: " + NFTMarket_V2_2Addr);

  const NFTMarket_V3Contract = await ethers.getContractFactory("NFTMarket_V3");
  const NFTMarket_V3 = await upgrades.upgradeProxy(NFTMarket_V2_2Addr, NFTMarket_V3Contract);
  const NFTMarket_V3Addr = NFTMarket_V3.target;
  console.log("NFTMarket_V3 contract has been deployed to: " + NFTMarket_V3Addr);

  const proxyAdminAddress = await upgrades.admin.getInstance();
  console.log("ProxyAdmin address:", proxyAdminAddress);

  // const ERC20TokenFactoryContract = await ethers.getContractFactory("ERC20TokenFactory");
  // const ERC20TokenFactory = await ERC20TokenFactoryContract.deploy(FairTokenGFTAddr);
  // await ERC20TokenFactory.waitForDeployment();
  // const ERC20TokenFactoryAddr = ERC20TokenFactory.target;
  // console.log("ERC20TokenFactory contract has been deployed to: " + ERC20TokenFactoryAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
