async function main() {
  // const boxAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // this address is used for testing on local hardhat network

  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Exchange = await ethers.getContractFactory("Exchange721");
  const exchange = await Exchange.deploy();

  console.log("Exchange address:", exchange.address);
  await exchange.connect(deployer).addOperator(deployer.address);
  // approve exchange
  //   const box = await ethers.getContractAt("BoxERC1155", boxAddress);
  //   await box.connect(deployer).setApprovalForAll(exchange.address, true);

  //   console.log(await box.isApprovedForAll(deployer.address, exchange.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
