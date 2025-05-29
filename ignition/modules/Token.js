// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");


module.exports = buildModule("TokenModule", (m) => {
  const suin = m.contract("Token", ["SUIN", "SUIN"], { id: "SuinToken" });
  const usdt = m.contract("Token", ["USDT", "USDT"], { id: "UsdtToken" });
  return { suin, usdt };
});
