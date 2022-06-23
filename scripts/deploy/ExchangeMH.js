async function main() {
    // const boxAddress = "0x042aF2636F718EB89b810Af75aD30c4139883d4F";
    const boxAddress = "0x042aF2636F718EB89b810Af75aD30c4139883d4F";

    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);  
  
    const Exchange = await ethers.getContractFactory("ExchangeMH");
    const exchange = await Exchange.deploy(boxAddress);
  
    console.log("Exhchange address:", exchange.address);

    // approve exchange
    const box = await ethers.getContractAt("BoxERC1155", boxAddress);
    await box.connect(deployer).setApprovalForAll(exchange.address, true);

    console.log(await box.isApprovedForAll(deployer.address, exchange.address));
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });