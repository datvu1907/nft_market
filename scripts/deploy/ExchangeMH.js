async function main() {
    const boxAddress = "0x681ACd32811a76794754c4139795e36f53a2F4d4";

    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);  
  
    const Exchange = await ethers.getContractFactory("ExchangeMH");
    const exchange = await Exchange.deploy(boxAddress);
  
    console.log("Exhchange address:", exchange.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });