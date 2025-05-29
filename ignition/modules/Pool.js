// ignition/modules/PoolModule.js

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const libModule = require("./LibModules");
const tokenModule = require("./Token");

module.exports = buildModule("PoolModule", (m) => {
  const libs = m.useModule(libModule);
  const { poolHelper, sqrtPriceMath, tickMath, position, swapMath, tickBitmap } = libs;

   const { suin, usdt } = m.useModule(tokenModule);


  const pool = m.contract("Pool", [suin, usdt, 1000000000000000000n], {
    libraries: {
      "contracts/lib/SqrtPriceMath.sol:SqrtPriceMath": sqrtPriceMath,
      "contracts/lib/TickMath.sol:TickMath": tickMath,
      // "contracts/lib/Position.sol:Position": position,
      // "contracts/lib/SwapMath.sol:SwapMath": swapMath,
      // "contracts/lib/TickBitmap.sol:TickBitmap": tickBitmap,
    },
  });

  return { pool };
});
