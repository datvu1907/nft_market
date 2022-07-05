const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Exchange721", function () {
  let admin;
  let user1;
  let user2;
  let creator;
  let operator;

  let exchange;
  let nft;
  let erc20token;

  beforeEach(async function () {
    [admin, user1, user2, operator, creator] = await ethers.getSigners();

    const ERC20TestToken = await ethers.getContractFactory(
      "ERC20TestToken",
      admin
    );
    erc20token = await ERC20TestToken.deploy();

    const NFT721 = await ethers.getContractFactory("NFT721", admin);
    nft = await NFT721.deploy();

    const Exchange721 = await ethers.getContractFactory("Exchange721", admin);
    exchange = await Exchange721.deploy();

    const erc20tokenAmount = 1000;

    await exchange.connect(admin).addOperator(admin.address);
    await exchange.connect(admin).addOperator(operator.address);

    await erc20token.connect(admin).addMinter(admin.address);
    await erc20token.connect(admin).mint(user2.address, erc20tokenAmount);
    await nft.connect(admin).mint(user1.address, 1);

    await erc20token.connect(user2).approve(exchange.address, erc20tokenAmount);
    await nft.connect(user1).setApprovalForAll(exchange.address, true);

    await exchange.connect(admin).setAdminAddress(admin.address);
    await exchange
      .connect(admin)
      .setCreatorAddress(creator.address, nft.address, 1);
    await exchange.connect(admin).setAdminFee(5);
    await exchange.connect(admin).setCreatorFee(10);
  });

  describe("Exchange ERC721 functions", function () {
    // it("Emit CreateSellOrder event", async function () {
    //   await expect(exchange.connect(user1).sell(1, 15, 7, erc20token.address))
    //     .to.emit(exchange, "CreateSellOrder")
    //     .withArgs(1, user1.address, 1, 15, 7, erc20token.address);
    //   // orderId, order.owner, order.tokenId, order.amount, order.price, order.currency
    // });
    it("Buy and sell natively", async function () {
      const adminOldBalance = await admin.getBalance();
      const creatorOldBalance = await creator.getBalance();
      const price = ethers.utils.parseEther("1");
      const msgValue = ethers.utils.parseEther("1"); // price = 1 ether
      const options = { value: msgValue };
      await exchange
        .connect(user1)
        .sell(nft.address, 1, price, ethers.constants.AddressZero);
      await exchange.connect(user2).buyNative(1, true, true, options);
      const balance = await user2.getBalance();
      expect(balance).to.be.lt(ethers.utils.parseEther("9999.0"));
      expect(balance).to.be.gt(ethers.utils.parseEther("9997.0"));
      const adminNewBalance = await admin.getBalance();
      const creatorNewBalance = await creator.getBalance();
      const ownerERC721 = await nft.ownerOf(1);
      expect(adminNewBalance.sub(adminOldBalance)).to.equal(
        ethers.utils.parseEther("0.05")
      );
      expect(creatorNewBalance.sub(creatorOldBalance)).to.equal(
        ethers.utils.parseEther("0.1")
      );

      expect(ownerERC721).to.equal(user2.address);
    });
    // it("Buy and sell using erc20", async function () {
    //   await exchange
    //     .connect(user1)
    //     .sell721(box.address, 1, 10, erc20token.address);
    //   await exchange.connect(user2).buy721(1, true, true);
    //   expect(await erc20token.balanceOf(user2.address)).to.equal(1000 - 100);
    //   expect(await box.balanceOf(user2.address, 1)).to.equal(10);
    //   expect(await erc20token.balanceOf(creator.address)).to.equal(10);
    //   expect(await erc20token.balanceOf(admin.address)).to.equal(5);
    // });
  });
  it("Accept offer", async function () {
    await exchange
      .connect(user1)
      .acceptOffer(
        nft.address,
        1,
        100,
        erc20token.address,
        user2.address,
        true,
        true
      );
    const user1Balance = await erc20token.balanceOf(user1.address);
    const user2NFTAmount = await nft.balanceOf(user2.address);
    expect(user1Balance).to.equal(85);
    expect(user2NFTAmount).to.equals(1);
  });
});
