// ignition/modules/NonfungiblePositionManagerModule.js

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const libModule = require("./LibModules");
const factoryModule = require("./Factory");

module.exports = buildModule("NonfungiblePositionManagerModule", (m) => {
  const libs = m.useModule(libModule);
  const { poolHelper, sqrtPriceMath, tickMath } = libs;

  const { factory } = m.useModule(factoryModule);

  const nonfungiblePositionManager = m.contract("NonfungiblePositionManager", [factory], {
    libraries: {
      "contracts/lib/PoolHelper.sol:PoolHelper": poolHelper,
      "contracts/lib/SqrtPriceMath.sol:SqrtPriceMath": sqrtPriceMath,
      "contracts/lib/TickMath.sol:TickMath": tickMath,
    },
  });

  return { nonfungiblePositionManager };
});
