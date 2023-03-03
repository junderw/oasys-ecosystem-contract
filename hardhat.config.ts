import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import "./tasks/bitbank";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.6.11",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.8.9",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
};

export default config;
