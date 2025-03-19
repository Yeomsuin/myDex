const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
  const { expect } = require("chai");
const { ethers } = require("hardhat");



describe("Deployment", function() {
    async function deployFixture() {
        const [owner, otherAccount] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("TokenA");
        const token = await Token.deploy("Test_Token", "TT");
        
        const Factory = await ethers.getContractFactory("Factory");
        const factory = await Factory.deploy();

        const Exchange = await ethers.getContractFactory("Exchange");
        const tx = await factory.createExchange(token.target);
        const receipt = await tx.wait();

        const exchange = await ethers.getContractAt("Exchange", receipt.logs[0].args[1]);
        // const exchange = await ethers.getContractAt("Exchange", await factory.getAddrToExchange(token.target));

        return {owner, otherAccount, token, Token, factory, exchange};
    }

        describe("Token", async function () {
            it("Should set the right owner", async function () {
                const {owner, token} = await loadFixture(deployFixture);
                expect(await token.owner()).to.equal(owner.address);
            })
            
            it("Owner mint init 100 tokens", async function () {
                const {owner, token} = await loadFixture(deployFixture);
                expect(await token.balanceOf(owner)).to.equal(ethers.parseEther("100"));
            })
        })
        
        describe("Factory", async function () {
            it("Should set the right owner", async function () {
                const {owner, factory} = await loadFixture(deployFixture);
                expect(await factory.owner()).to.equal(owner.address);
            })

            it("Should fail if exchange already exist for a token", async function() {
                const {factory, token} = await loadFixture(deployFixture);
                await expect(factory.createExchange(token.target)).to.be.reverted;
            })

            it("Should correctly map addrToExchange and exchangeToAddr", async function () {
                const {factory, exchange, token} = await loadFixture(deployFixture);
                const exchangeAddr = await exchange.getAddress();
                const mappingAddr = await factory.getExchangeToAddr(exchangeAddr);
                const mappingExchange = await factory.getAddrToExchange(token.target)
                expect(mappingExchange).to.equal(exchangeAddr);
                expect(mappingAddr).to.equal(token.target);
            })
        })

        describe("Exchange", async function () {
            it("Should set the right owner", async function () {
                const {factory, exchange} = await loadFixture(deployFixture);
                expect(await exchange.owner()).to.equal(await factory.getAddress());
            })
        })

});