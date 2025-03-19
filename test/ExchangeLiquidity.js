const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
const { ethers } = require("hardhat");



describe("Exchange: Liquidity", function() {
    async function deployFixture() {
        const [owner, otherAccount] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("TokenA");
        const token = await Token.deploy("Test Token", "TT");
        
        const Factory = await ethers.getContractFactory("Factory");
        const factory = await Factory.deploy();

        const Exchange = await ethers.getContractFactory("Exchange");
        const tx = await factory.createExchange(token.target);
        const receipt = await tx.wait();

        const exchange = await ethers.getContractAt("Exchange", receipt.logs[0].args[1]);
        // const exchange = await ethers.getContractAt("Exchange", await factory.getAddrToExchange(token.target));

        return {owner, otherAccount, token, Token, factory, exchange};
    }

    it("Should 'Add Liquidity' correctly", async function() {
        const {exchange } = await loadFixture(deployFixture);
        const amount =await exchange.getOutputAmount(ethers.parseEther("10.0"));
        
    })


    it("Should 'Remove Liquidity' correctly", async function () {

        
        
    })

})