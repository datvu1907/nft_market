require('dotenv').config();
require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.0",
  networks: {
    spectretestnet: {
      url: "https://testnet.spectre-rpc.com",
      chainId: 55,
      gasPrice: 20000000000,
      accounts: {mnemonic: process.env.MNEMONIC || ''}
    }
  }
};
