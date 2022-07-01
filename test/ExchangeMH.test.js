const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("ExchangeMH", function () {
  let admin;
  let user1;
  let user2;
  let creator;

  let exchange;
  let box;
  let nft;
  let erc20token;

  beforeEach(async function () {
    [admin, user1, user2, creator] = await ethers.getSigners();

    const ERC20TestToken = await ethers.getContractFactory(
      "ERC20TestToken",
      admin
    );
    erc20token = await ERC20TestToken.deploy();

    const NFTMysteryBox = await ethers.getContractFactory(
      "NFTMysteryBox",
      admin
    );
    box = await NFTMysteryBox.deploy();

    const NFT721 = await ethers.getContractFactory("NFT721", admin);
    nft = await NFT721.deploy();

    const ExchangeMH = await ethers.getContractFactory("ExchangeMH", admin);
    exchange = await ExchangeMH.deploy();

    const erc20tokenAmount = 1000;
    const boxAmount = 20;

    await erc20token.connect(admin).addMinter(admin.address);
    await erc20token.connect(admin).mint(user2.address, erc20tokenAmount);
    await box.connect(admin).mint(user1.address, 1, boxAmount, "0x00");
    await nft.connect(admin).mint(user1.address, 1);

    await erc20token.connect(user2).approve(exchange.address, erc20tokenAmount);
    await box.connect(user1).setApprovalForAll(exchange.address, true);
    await nft.connect(user1).setApprovalForAll(exchange.address, true);

    await exchange.connect(admin).setAdminAddress(admin.address);
    await exchange
      .connect(admin)
      .setCreatorAddress(creator.address, box.address, 1);
    await exchange.connect(admin).setAdminFee(5);
    await exchange.connect(admin).setCreatorFee(10);
  });

  describe("Exchange ERC1155 functions", function () {
    // it("Emit CreateSellOrder event", async function () {
    //   await expect(exchange.connect(user1).sell(1, 15, 7, erc20token.address))
    //     .to.emit(exchange, "CreateSellOrder")
    //     .withArgs(1, user1.address, 1, 15, 7, erc20token.address);
    //   // orderId, order.owner, order.tokenId, order.amount, order.price, order.currency
    // });

    it("Buy and sell natively", async function () {
      const adminOldBalance = await admin.getBalance();
      const creatorOldBalance = await creator.getBalance();
      const pricePerBox = ethers.utils.parseEther("0.1");
      const msgValue = ethers.utils.parseEther("1"); // price = 1 ether
      const options = { value: msgValue };
      await exchange
        .connect(user1)
        .sell(box.address, 1, 10, pricePerBox, ethers.constants.AddressZero);
      await exchange.connect(user2).buyNative(1, 10, true, true, options);

      const balance = await user2.getBalance();
      expect(balance).to.be.lt(ethers.utils.parseEther("9999.0"));
      expect(balance).to.be.gt(ethers.utils.parseEther("9998.99"));
      const adminNewBalance = await admin.getBalance();
      const creatorNewBalance = await creator.getBalance();
      expect(adminNewBalance.sub(adminOldBalance)).to.equal(
        ethers.utils.parseEther("0.05")
      );
      expect(creatorNewBalance.sub(creatorOldBalance)).to.equal(
        ethers.utils.parseEther("0.1")
      );
    });

    it("Buy and sell using erc20", async function () {
      await exchange
        .connect(user1)
        .sell(box.address, 1, 10, 10, erc20token.address);
      await exchange.connect(user2).buy(1, 10, true, true);

      expect(await erc20token.balanceOf(user2.address)).to.equal(1000 - 100);
      expect(await box.balanceOf(user2.address, 1)).to.equal(10);

      expect(await erc20token.balanceOf(creator.address)).to.equal(10);
      expect(await erc20token.balanceOf(admin.address)).to.equal(5);
    });

    it("updateOrder(): change price of order", async function () {
      await exchange
        .connect(user1)
        .sell(box.address, 1, 15, 7, erc20token.address);
      await exchange.connect(user1).updateOrder(1, 14);

      const order = await exchange.orders(1);
      expect(order.pricePerBox).to.equal(14);
    });

    it("increaseAmount(): increase amount of boxes", async function () {
      await exchange
        .connect(user1)
        .sell(box.address, 1, 12, 7, erc20token.address);

      const boxOfExchangeBefore = await box.balanceOf(exchange.address, 1);
      const amountToAdd = 4;

      await exchange.connect(user1).increaseAmount(1, amountToAdd);

      const order = await exchange.orders(1);
      expect(order.amount).to.equal(16); // 12 + 4
      expect(await box.balanceOf(exchange.address, 1)).to.equal(
        boxOfExchangeBefore.add(amountToAdd)
      );
    });
    it("Accept offer", async function () {
      await exchange
        .connect(user1)
        .acceptOffer(
          box.address,
          1,
          10,
          100,
          erc20token.address,
          user2.address,
          true,
          false
        );
      const user1Balance = await erc20token.balanceOf(user1.address);
      const user2NFTAmount = await box.balanceOf(user2.address, 1);
      expect(user1Balance).to.equal(95);
      expect(user2NFTAmount).to.equals(10);
    });

    // it("Revert if buyer pays ERC20 token but seller wants native token", async function () {
    //   const msgValue = ethers.utils.parseEther("1.0"); // price = 1 ether
    //   await exchange
    //     .connect(user1)
    //     .sell(1, 15, msgValue, ethers.constants.AddressZero);

    //   await expect(exchange.connect(user2).buy(1)).to.be.revertedWith(
    //     "Order requires being paid by native currency, use buyNative() instead"
    //   );
    // });

    // it("Revert if buyer pays native token but seller wants ERC20 token", async function () {
    //   const msgValue = ethers.utils.parseEther("0.000000007"); // price = 7000000000 wei
    //   const options = await { value: msgValue };
    //   await exchange.connect(user1).sell(1, 15, 7000000000, erc20token.address);

    //   await expect(
    //     exchange.connect(user2).buyNative(1, options)
    //   ).to.be.revertedWith(
    //     "Order requires being paid by erc20 currency, use buy() instead"
    //   );
    // });
    // // function acceptOffer(uint256 _tokenId, uint256 _amount, uint256 _pricePerBox, address _currency, address _userOffer) external {
    // it("Accept an offer", async function () {
    //   await exchange
    //     .connect(user1)
    //     .acceptOffer(1, 5, 2, erc20token.address, user2.address);

    //   expect(await box.balanceOf(user2.address, 1)).to.equal(5);
    //   expect(await erc20token.balanceOf(user2.address)).to.equal(1000 - 10);
    // });
  });

  // describe("Exchange ERC721 functions", function () {
  //   // it("Emit CreateSellOrder event", async function () {
  //   //   await expect(exchange.connect(user1).sell(1, 15, 7, erc20token.address))
  //   //     .to.emit(exchange, "CreateSellOrder")
  //   //     .withArgs(1, user1.address, 1, 15, 7, erc20token.address);
  //   //   // orderId, order.owner, order.tokenId, order.amount, order.price, order.currency
  //   // });

  //   it("Buy and sell natively", async function () {
  //     const adminOldBalance = await admin.getBalance();
  //     const creatorOldBalance = await creator.getBalance();
  //     const pricePerBox = ethers.utils.parseEther("0.1");
  //     const msgValue = ethers.utils.parseEther("1"); // price = 1 ether
  //     const options = { value: msgValue };
  //     await exchange
  //       .connect(user1)
  //       .sell721(nft.address, 1, pricePerBox, ethers.constants.AddressZero);
  //     await exchange.connect(user2).buy721Native(1, true, true, options);

  //     // const balance = await user2.getBalance();
  //     // expect(balance).to.be.lt(ethers.utils.parseEther("9999.0"));
  //     // expect(balance).to.be.gt(ethers.utils.parseEther("9998.99"));
  //     // const adminNewBalance = await admin.getBalance();
  //     // const creatorNewBalance = await creator.getBalance();
  //     // expect(adminNewBalance.sub(adminOldBalance)).to.equal(
  //     //   ethers.utils.parseEther("0.05")
  //     // );
  //     // expect(creatorNewBalance.sub(creatorOldBalance)).to.equal(
  //     //   ethers.utils.parseEther("0.1")
  //     // );
  //   });

  //   // it("Buy and sell using erc20", async function () {
  //   //   await exchange
  //   //     .connect(user1)
  //   //     .sell721(box.address, 1, 10, erc20token.address);
  //   //   await exchange.connect(user2).buy721(1, true, true);

  //   //   expect(await erc20token.balanceOf(user2.address)).to.equal(1000 - 100);
  //   //   expect(await box.balanceOf(user2.address, 1)).to.equal(10);

  //   //   expect(await erc20token.balanceOf(creator.address)).to.equal(10);
  //   //   expect(await erc20token.balanceOf(admin.address)).to.equal(5);
  //   // });
  // });
});
