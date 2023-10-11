require("@nomicfoundation/hardhat-toolbox");
require("hardhat-abi-exporter");
require("hardhat-gas-reporter");
require('dotenv').config()

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        enabled: true,
        url: process.env.MAINNET_RPC,
      },
      chainId: 1,
    },
  },
  abiExporter: [
    {
      path: "./contracts/abi/pretty",
      clear: true,
      flat: true,
      pretty: true,
      spacing: 2,
    },
    {
      path: "./contracts/abi/ugly",
      clear: true,
      flat: true,
      pretty: false,
      spacing: 2,
    },
  ],
  gasReporter: {
    enabled: true,
    coinmarketcap: process.env.COINMARKETCAP_API,
    currency: "USD",
    token: "ETH",
    gasPriceApi:
        "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
