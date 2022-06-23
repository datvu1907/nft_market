const { ethers } = require('hardhat');
const { expect } = require('chai');

describe("ExchangeMH", function () {
    let admin;
    let user1;
    let user2;
    let user3;

    let exchange;
    let box;
    let erc20token;

    beforeEach(async function () {

        [admin, user1, user2, user3] = await ethers.getSigners();

        const ERC20TestToken = await ethers.getContractFactory("ERC20TestToken", admin);
        erc20token = await ERC20TestToken.deploy();

        const NFTMysteryBox = await ethers.getContractFactory("NFTMysteryBox", admin);
        box = await NFTMysteryBox.deploy();

        const ExchangeMH = await ethers.getContractFactory("ExchangeMH", admin);
        exchange = await ExchangeMH.deploy(box.address);

        const erc20tokenAmount = 1000;
        const boxAmount = 20;

        await erc20token.connect(admin).addMinter(admin.address);
        await erc20token.connect(admin).mint(user2.address, erc20tokenAmount);
        await box.connect(admin).mint(user1.address, 1, boxAmount, '0x00');

        await erc20token.connect(user2).approve(exchange.address, erc20tokenAmount);
        await box.connect(user1).setApprovalForAll(exchange.address, true);
    });

    describe('Exchange functions', function () {
        it("Emit CreateSellOrder event", async function () {    
            await expect(exchange.connect(user1).sell(1, 15, 7, erc20token.address))
                .to.emit(exchange, 'CreateSellOrder')
                .withArgs(1, user1.address, 1, 15, 7, erc20token.address);
                // orderId, order.owner, order.tokenId, order.amount, order.price, order.currency
        });

        it("Buy and sell natively", async function () {
            const msgValue = ethers.utils.parseEther("1.0"); // price = 1 ether
            const options = await {value: msgValue};
            await exchange.connect(user1).sell(1, 15, msgValue, ethers.constants.AddressZero);
            await exchange.connect(user2).buyNative(1, options);

            const balance = await user2.getBalance();
            expect(balance).to.be.lt(ethers.utils.parseEther("9999.0"));
            expect(balance).to.be.gt(ethers.utils.parseEther("9998.99"));
        });

        it("Buy and sell using erc20", async function () {
            await exchange.connect(user1).sell(1, 15, 7, erc20token.address);
            await exchange.connect(user2).buy(1);

            expect(await erc20token.balanceOf(user2.address)).to.equal(1000-7);
            expect(await box.balanceOf(user2.address, 1)).to.equal(15);
        });

        it("Order is deleted after buying", async function () {
            await exchange.connect(user1).sell(1, 15, 7, erc20token.address);
            await exchange.connect(user2).buy(1);

            const orderInfo = await exchange.orders(1);
            expect(orderInfo.owner).to.equal(ethers.constants.AddressZero);
        });

        it("Revert if buyer pays ERC20 token but seller wants native token", async function () {
            const msgValue = ethers.utils.parseEther("1.0"); // price = 1 ether
            await exchange.connect(user1).sell(1, 15, msgValue, ethers.constants.AddressZero);

            await expect(exchange.connect(user2).buy(1))
                .to.be.revertedWith("Order requires being paid by native currency, use buyNative() instead");
        });

        it("Revert if buyer pays native token but seller wants ERC20 token", async function () {
            const msgValue = ethers.utils.parseEther("0.000000007"); // price = 7000000000 wei
            const options = await {value: msgValue};
            await exchange.connect(user1).sell(1, 15, 7000000000, erc20token.address);

            await expect(exchange.connect(user2).buyNative(1, options))
                .to.be.revertedWith("Order requires being paid by erc20 currency, use buy() instead");
        });
        // function acceptOffer(uint256 _tokenId, uint256 _amount, uint256 _pricePerBox, address _currency, address _userOffer) external {
        it("Accept an offer", async function () {
            await exchange.connect(user1).acceptOffer(1, 5, 2, erc20token.address, user2.address);

            expect(await box.balanceOf(user2.address, 1)).to.equal(5);
            expect(await erc20token.balanceOf(user2.address)).to.equal(1000-10);
        });
    });
});