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
        // async function deployContracts() {
        //     const ERC20TestToken = await ethers.getContractFactory("ERC20TestToken", admin);
        //     erc20token = await ERC20TestToken.deploy();
    
        //     const NFTMysteryBox = await ethers.getContractFactory("NFTMysteryBox", admin);
        //     box = await NFTMysteryBox.deploy();
    
        //     const ExchangeMH = await ethers.getContractFactory("ExchangeMH", admin);
        //     exchange = await ExchangeMH.deploy(box.address, erc20token.address);
        // }
    
        // async function mintTokensAndSetApproval() {
        //     const erc20tokenAmount = 1000;
        //     const boxAmount = 20;
    
        //     await erc20token.connect(admin).mint(user2.address, erc20tokenAmount);
        //     await box.connect(admin).mint(user1.address, 1, boxAmount, '');
    
        //     await erc20token.connect(user2).approve(exchange.adress, erc20tokenAmount);
        //     await box.connect(admin).setApprovalForAll(exchange.adress, true);
        // }

        [admin, user1, user2, user3] = await ethers.getSigners();

        const ERC20TestToken = await ethers.getContractFactory("ERC20TestToken", admin);
        erc20token = await ERC20TestToken.deploy();

        const NFTMysteryBox = await ethers.getContractFactory("NFTMysteryBox", admin);
        box = await NFTMysteryBox.deploy();

        const ExchangeMH = await ethers.getContractFactory("ExchangeMH", admin);
        exchange = await ExchangeMH.deploy(box.address, erc20token.address);

        const erc20tokenAmount = 1000;
        const boxAmount = 20;

        await erc20token.connect(admin).mint(user2.address, erc20tokenAmount);
        await box.connect(admin).mint(user1.address, 1, boxAmount, '0x00');

        await erc20token.connect(user2).approve(exchange.address, erc20tokenAmount);
        await box.connect(user1).setApprovalForAll(exchange.address, true);

        // deployContracts();

        // mintTokensAndSetApproval();
    });

    describe('Sell', function () {
        it("Emit CreateSellOrder event", async function () {    
            await expect(exchange.connect(user1).sell(1, 15, 7))
                .to.emit(exchange, 'CreateSellOrder')
                .withArgs(1, user1.address, 1, 15, 7);
        });
    }); 
});