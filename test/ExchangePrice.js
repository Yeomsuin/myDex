// const {
//     loadFixture,
//   } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
//   const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
//   const { expect } = require("chai");
// const { ethers } = require("hardhat");



// describe("Exchange: Price Discovery Function", function() {
//     async function deployFixture() {
//         const [owner, otherAccount] = await ethers.getSigners();

//         const Token = await ethers.getContractFactory("TokenA");
//         const token = await Token.deploy("Test Token", "TT");
        
//         const Factory = await ethers.getContractFactory("Factory");
//         const factory = await Factory.deploy();

//         const Exchange = await ethers.getContractFactory("Exchange");
//         const tx = await factory.createExchange(token.target);
//         const receipt = await tx.wait();

//         const exchange = await ethers.getContractAt("Exchange", receipt.logs[0].args[1]);
//         // const exchange = await ethers.getContractAt("Exchange", await factory.getAddrToExchange(token.target));

//         return {owner, otherAccount, token, Token, factory, exchange};
//     }

//     it("Should correctly calculate 'output price'", async function() {
//         const {exchange } = await loadFixture(deployFixture);
//         const amount =await exchange.getOutputAmount(ethers.parseEther("10.0"));
//         const x = ethers.parseEther("100.0");
//         const y = ethers.parseEther("100.0");
//         const dx = ethers.parseEther("10.0");
//         const dy = y * dx / (x + dx) *  997n / 1000n;
//         await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dy));
//     })

//     it("Should correctly calculate 'input price'", async function() {
//         const {exchange } = await loadFixture(deployFixture);
//         const amount =await exchange.getInputAmount(ethers.parseEther("10.0"));
//         const x = ethers.parseEther("100.0");
//         const y = ethers.parseEther("100.0");
//         const dy = ethers.parseEther("10.0");
//         const dx = x * dy / (y - dy) *  1000n / 997n;
//         await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dx));
//     })



// })