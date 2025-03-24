const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
  const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

let LP, alice, bob, suin, usdt, factory, pair, router, library, flag, token0, token1, amount0, amount1;
const decimals = ethers.parseEther("1");

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


    [token0, token1, flag] = suin < usdt ? [suin, usdt, false] : [usdt, suin, true];
    return {owner, LP, alice, bob, suin, usdt, Token, factory, pair, router, flag, library};
}

before(async function () {
    ({ owner, LP, alice, bob, suin, usdt, Token, factory, pair, router, flag, library } = await deployFixture());
});

function scailing(amount) {
    return Number(amount) / Number(decimals);
}

describe("myDex", function() {
    describe("Deployment", async function () {
        describe("Token", async function () {
            it("Should set the right owner", async function () {
                expect(await suin.owner()).to.equal(owner.address);
                expect(await usdt.owner()).to.equal(owner.address);
            })
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
            expect(await suin.balanceOf(LP)).to.equal(ethers.parseEther("100"));
            expect(await suin.balanceOf(alice)).to.equal(ethers.parseEther("1"));
        })

        it("Shound correctly mint init 10000/100 USDT tokens to LP/Users", async function() {
            await usdt.mint(LP, ethers.parseEther("10000"));
            await usdt.mint(bob, ethers.parseEther("100"));
            expect(await usdt.balanceOf(LP)).to.equal(ethers.parseEther("10000"));
            expect(await usdt.balanceOf(bob)).to.equal(ethers.parseEther("100"));
        })
    })


    describe("Liquidity", async function () {
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

    describe("Pricing", async function () {
        it("Should correctly calculate 'quote price'", async function() {
            const rx = ethers.parseEther("10000.0");
            const ry = ethers.parseEther("100.0");
            const x = ethers.parseEther("10.0");
            const amount =await library.quote(x, rx, ry);  
            const res = x * ry / rx;
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(res));
        })
    

        it("Should correctly calculate 'output price'", async function() {
            let [x, y] = await pair.getReserves();
            const dx = ethers.parseEther("2");
            [x, y] = flag ? [y, x] : [x, y];
            const amount = await library.getOutputAmount(factory, suin, usdt, dx); 
            const dxWithFee = dx * 997n;
            const dy = y * dxWithFee / (x * 1000n + dxWithFee);
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dy));
        })

        it("Should correctly calculate 'input price'", async function() {
            let [x, y] = await pair.getReserves();
            const dy = ethers.parseEther("10.0");
            [x, y] = flag ? [y, x] : [x, y];
            const amount = await library.getInputAmount(factory, suin, usdt, dy);
            const dx = x * dy / (y - dy) *  1000n / 997n + 1n;
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dx));
        })
    
    })

    describe("Swap", async function () {

        // * 추가 정렬 순서에 따른 swap test case 구현 
            // 100, 10000
            it("Should correctly swap exact token-to-token by asc", async function() {
                let [reserve0, reserve1] = await pair.getReserves();
                let amountIn = "0.2";
                if(flag) [reserve0, reserve1] = [reserve1, reserve0];        
                let amountOut = ethers.parseEther(amountIn) * 997n * reserve1 / (reserve0 * 1000n + ethers.parseEther(amountIn) * 997n);
                let beforeBalance = await suin.balanceOf(alice);
                await suin.connect(alice).approve(router.target, ethers.parseEther(amountIn));
                await router.connect(alice).swapExactTokenToToken(suin, usdt, ethers.parseEther(amountIn), 0, alice);
                expect(await suin.balanceOf(alice)).to.equal(beforeBalance - ethers.parseEther(amountIn));
                expect(await usdt.balanceOf(alice)).to.equal(amountOut);
            }) 
    
            // it("Should correctly swap exact token-to-token by desc", async function() {
            //     let [reserve0, reserve1] = await pair.getReserves();
            //     let amountIn = "0.2";
            //     let amountOut = ethers.parseEther(amountIn) * 997n * reserve1 / (reserve0 * 1000n + ethers.parseEther(amountIn) * 997n);
            //     let beforeBalance = await suin.balanceOf(alice);
            //     await suin.connect(alice).approve(router.target, ethers.parseEther(amountIn));
            //     await router.connect(alice).swapExactTokenToToken(suin, usdt, ethers.parseEther(amountIn), 0, alice);
            //     expect(await suin.balanceOf(alice)).to.equal(beforeBalance - ethers.parseEther(amountIn));
            //     expect(await usdt.balanceOf(alice)).to.equal(amountOut);
            // }) 
    
    
            
            // it("Should correctly swap token-to-exact token by asc", async function() {
            //     let [reserve0, reserve1] = await pair.getReserves();
            //     let amountOut = "0.2";
            //     let beforeBalance = await usdt.balanceOf(bob);
            //     if(flag) [reserve0, reserve1] = [reserve1, reserve0]; 
            //     let amountIn = reserve1 * ethers.parseEther(amountOut) * 1000n / (reserve0 - ethers.parseEther(amountOut) * 997n) + 1n;
            //     let amountInWithResidual = (amountIn * ethers.parseEther("1.1")).toString();
            //     console.log(scailing( reserve1 * ethers.parseEther(amountOut) * 1000n), scailing((reserve0 - ethers.parseEther(amountOut) * 997n)));
            //     await usdt.connect(bob).approve(router.target, ethers.parseEther(amountInWithResidual));
            //     await router.connect(bob).swapTokenToExactToken(usdt, suin, ethers.parseEther(amountOut), amountInWithResidual, bob);
            //     expect(await usdt.balanceOf(bob)).to.equal(ethers.parseEther(beforeBalance - ethers.parseEther(amountOut)));
            //     expect(await suin.balanceOf(bob)).to.equal(ethers.parseEther(ret.toString()));
            // })
    
            it("Should correctly swap token-to-exact token by desc", async function() {
                let [reserve0, reserve1] = await pair.getReserves();
                let amountOut = "0.2";
                let beforeBalance = await usdt.balanceOf(bob);
                if(flag) [reserve0, reserve1] = [reserve1, reserve0]; 
                let amountIn = reserve1 * ethers.parseEther(amountOut) * 1000n / ((reserve0 - ethers.parseEther(amountOut)) * 997n) + 1n;
                let amountInWithResidual = (amountIn * ethers.parseEther("1.1")).toString();
                await usdt.connect(bob).approve(router.target, ethers.parseEther(amountInWithResidual));
                await router.connect(bob).swapTokenToExactToken(usdt, suin, ethers.parseEther(amountOut), ethers.parseEther(amountInWithResidual), bob);
                expect(await suin.balanceOf(bob)).to.equal(ethers.parseEther(amountOut));
                expect(await usdt.balanceOf(bob)).to.equal(beforeBalance - amountIn);
            })
    })
});