// ignition/modules/LibModule.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LibModules", (m) => {
  const poolHelper = m.library("PoolHelper");
  const sqrtPriceMath = m.library("SqrtPriceMath");
  const tickMath = m.library("TickMath");
  const bitMath = m.library("BitMath");
  const position = m.library("Position");
  const swapMath = m.library("SwapMath");
  const tick = m.library("Tick");
  const tickBitmap = m.library("TickBitmap");

  return {
    poolHelper,
    sqrtPriceMath,
    tickMath,
    bitMath,
    position,
    swapMath,
    tick,
    tickBitmap,
  };
});
