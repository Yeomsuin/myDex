require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-ignition-ethers");
require("hardhat-docgen");
const { vars } = require("hardhat/config");
const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");
const ALCHEMY_API_KEY = vars.get("ALCHEMY_API_KEY");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");

module.exports = {
  solidity: "0.8.28",
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [`0x${PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
    }
  },
  docgen: {
    path: "./docs",
    clear: true,
   // runOnCompile: true,
  },
}