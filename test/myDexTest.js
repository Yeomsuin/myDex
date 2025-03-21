const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
  const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

let LP, alice, bob, suin, usdt, factory, pair, router;

async function deployFixture() {
    const [owner, LP, alice, bob] = await ethers.getSigners();

    // 수정해야 할수도
    const Library = await ethers.getContractFactory("Library");
    const library = await Library.deploy();

    const Token = await ethers.getContractFactory("Token");
    const suin = await Token.deploy("SUIN-COIN", "SUIN");
    const usdt = await Token.deploy("US-TEDDER", "USDT");

    const Factory = await ethers.getContractFactory("Factory", {
        libraries: {
            Library: library.target,
        },
    });

    const factory = await Factory.deploy();

    const Pair = await ethers.getContractFactory("Pair");
    const tx = await factory.createPair(suin.target, usdt.target);
    const receipt = await tx.wait();

    const pair = await ethers.getContractAt("Pair", receipt.logs[0].args[2]);

    const Router = await ethers.getContractFactory("Router", {
        libraries: {
            Library: library.target,
        },
    });
    const router = await Router.deploy(factory.target);
    return {owner, LP, alice, bob, suin, usdt, Token, factory, pair, router};
}

before(async function () {
    ({ owner, LP, alice, bob, suin, usdt, Token, factory, pair, router } = await deployFixture());
});


describe("myDex", function() {
    describe("Deployment", async function () {
        describe("Token", async function () {
            it("Should set the right owner", async function () {
                expect(await suin.owner()).to.equal(owner.address);
                expect(await usdt.owner()).to.equal(owner.address);
            })
            
            /* 후 mint에 사용
            it("Shound mint init 100/1 SUIN tokens to LP/Users", async function () {
                const {LP, alice, bob, suin} = await loadFixture(deployFixture);
                expect(await suin.balanceOf(LP)).to.equal(ethers.parseEther("100"));
                expect(await suin.balanceOf(alice)).to.equal(ethers.parseEther("1"));
                expect(await suin.balanceOf(bob)).to.equal(ethers.parseEther("1"));
            })

            it("Shount mint init 10000/100 USDT tokens to LP/Users", async function () {
                const {LP, alice, bob, usdt} = await loadFixture(deployFixture);
                expect(await usdt.balanceOf(LP)).to.equal(ethers.parseEther("10000"));
                expect(await usdt.balanceOf(alice)).to.equal(ethers.parseEther("100"));
                expect(await usdt.balanceOf(bob)).to.equal(ethers.parseEther("100"));
            })
                */
        })
        
        describe("Factory", async function () {
            it("Should set the right owner", async function () {
                expect(await factory.owner()).to.equal(owner.address);
            })

            it("Should fail if pair already exist for tokens", async function() {
                await expect(factory.createPair(suin.target, usdt.target)).to.be.reverted;
            })

            it("Should fail if pair already exist for reversed tokens", async function() {
                await expect(factory.createPair(usdt.target, suin.target)).to.be.reverted;
            })

            it("Should correctly map tokens to pair", async function () {
                const mappingAddr = await factory.getTokensToPair(suin.target, usdt.target);
                expect(mappingAddr).to.equal(pair.target);
            })
        })

        describe("Pair", async function () {
            it("Should set the right owner", async function () {
                const Pair = await ethers.getContractAt("Pair", pair);
                expect(await Pair.owner()).to.equal(await factory.getAddress());
            })
        })
    })
    

    describe("Mint Tokens", async function () {
        it("Shound correctly mint init 100/1 SUIN tokens to LP/Users", async function() {
            suin.mint(LP, ethers.parseEther("100"));
            await suin.mint(alice, ethers.parseEther("1"));
            await suin.mint(bob, ethers.parseEther("1"));
            expect(await suin.balanceOf(LP)).to.equal(ethers.parseEther("100"));
            expect(await suin.balanceOf(alice)).to.equal(ethers.parseEther("1"));
            expect(await suin.balanceOf(bob)).to.equal(ethers.parseEther("1"));
        })

        it("Shound correctly mint init 10000/100 USDT tokens to LP/Users", async function() {
            await usdt.mint(LP, ethers.parseEther("10000"));
            await usdt.mint(alice, ethers.parseEther("100"));
            await usdt.mint(bob, ethers.parseEther("100"));
            expect(await usdt.balanceOf(LP)).to.equal(ethers.parseEther("10000"));
            expect(await usdt.balanceOf(alice)).to.equal(ethers.parseEther("100"));
            expect(await usdt.balanceOf(bob)).to.equal(ethers.parseEther("100"));
        })
    })


    describe("Simple Liquidity", async function () {
        it("Should correctly init add liquidity", async function() {
            await suin.connect(LP).approve(router.target, ethers.parseEther("100"));
            await usdt.connect(LP).approve(router.target, ethers.parseEther("10000"));
            await router.connect(LP).addLiquidity(suin, usdt, ethers.parseEther("100"), ethers.parseEther("10000"), 0, 0, LP);
            expect(await suin.balanceOf(pair.target)).to.equal(ethers.parseEther("100"));
            expect(await usdt.balanceOf(pair.target)).to.equal(ethers.parseEther("10000"));
            expect(await pair.balanceOf(LP)).to.equal(ethers.parseEther("1000"));
        })

        it("Should correctly remove liquidity", async function() {
            await pair.connect(LP).approve(router.target, ethers.parseEther("500"));
            await router.connect(LP).removeLiquidity(suin, usdt, ethers.parseEther("500"), LP);
            expect(await suin.balanceOf(pair.target)).to.equal(ethers.parseEther("50"));
            expect(await usdt.balanceOf(pair.target)).to.equal(ethers.parseEther("5000"));
            expect(await pair.balanceOf(LP)).to.equal(ethers.parseEther("500"));

            // 원상 복구
            await suin.connect(LP).approve(router.target, ethers.parseEther("50"));
            await usdt.connect(LP).approve(router.target, ethers.parseEther("5000"));
            await router.connect(LP).addLiquidity(suin, usdt, ethers.parseEther("50"), ethers.parseEther("5000"), 0, 0, LP);
            expect(await suin.balanceOf(pair.target)).to.equal(ethers.parseEther("100"));
            expect(await usdt.balanceOf(pair.target)).to.equal(ethers.parseEther("10000"));
            expect(await pair.balanceOf(LP)).to.equal(ethers.parseEther("1000"));
        })

    })
});