require("dotenv").config();
require("hardhat-tracer");
require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.1",
  networks: {
    spectretestnet: {
      url: "https://testnet.spectre-rpc.io",
      chainId: 55,
      gasPrice: 20000000000,
      accounts: [process.env.SHARED_PRIV_KEY],
      // accounts: {mnemonic: process.env.MNEMONIC || ''}
    },
  },
};
