const { expect } = require("chai");
const { ethers } = require("hardhat");

let hardhatToken;
let owner;
let addr1;
let addr2;
let addrs;
let Token;

beforeEach(async () => {
  boxToken = await ethers.getContractFactory("NFTMysteryBox");
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  hardhatToken = await boxToken.deploy();
});
describe("List NFT to Exchange", function () {
  it("List NFT", async function () {
    exchange = await ethers.getContractFactory("ExchangeNFT");
    exchangeToken = await exchange.deploy(hardhatToken.adress);
    await exchangeToken
      .connect(owner)
      .listingNFTToExchange(1, "Normal x1", 0, 0, 1, 0);
  });
});
