// ignition/modules/SwapRouterModule.js

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const libModule = require("./LibModules");
const factoryModule = require("./Factory");

module.exports = buildModule("SwapRouterModule", (m) => {
  const libs = m.useModule(libModule);
  const { poolHelper } = libs;
  const { factory } = m.useModule(factoryModule);

  const swapRouter = m.contract("SwapRouter", [factory], {
    libraries: {
      // "contracts/lib/PoolHelper.sol:PoolHelper": poolHelper,
    },
  });

  return { swapRouter };
});
