import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

require("dotenv").config();
const {
  API_URL_SEPOLIA,
  API_URL_AMOY,
  PRIVATE_KEY,
} = process.env;

const config: HardhatUserConfig = {

  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      }
    }
  },
  networks: {
    hardhat: {},
    amoy: {
      url: API_URL_AMOY,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    sepolia: {
      url: API_URL_SEPOLIA,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
};

export default config;


