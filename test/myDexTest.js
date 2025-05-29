const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
  const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

let LP, alice, bob, suin, usdt, factory, pool, poolHelper, flag, token0, token1, position, sqrtPriceMath, tick, tickMath, nonfungiblePositionManager;
let tickBitmap, swapMath, swapRouter, params;
const decimals = ethers.parseEther("1");
const Q96 = 1n << 96n;
let sqrtPriceX96, sqrtPrice, tokenId = 1;

function scaling(amount) {
    return Number(amount) / Number(decimals);
}

function getSqrtPriceX96FromSqrtPrice(price) {
    return BigInt(price * Number(Q96)); 
}

async function deployFixture() {
    [owner, LP, alice, bob, trump] = await ethers.getSigners();

    const PoolHelper = await ethers.getContractFactory("PoolHelper");
    poolHelper = await PoolHelper.deploy();
    const Tick = await ethers.getContractFactory("Tick");
    tick = await Tick.deploy();
    const TickMath = await ethers.getContractFactory("TickMath");
    tickMath = await TickMath.deploy();
    const SqrtPriceMath = await ethers.getContractFactory("SqrtPriceMath");
    sqrtPriceMath = await SqrtPriceMath.deploy();
    const Position = await ethers.getContractFactory("Position");
    position = await Position.deploy();
    const BitMath = await ethers.getContractFactory("BitMath");
    bitMath = await BitMath.deploy();
    const SwapMath = await ethers.getContractFactory("SwapMath");
    swapMath = await SwapMath.deploy();
    const TickBitmap = await ethers.getContractFactory("TickBitmap");
    tickBitmap = await TickBitmap.deploy();

    const Token = await ethers.getContractFactory("Token");
    suin = await Token.deploy("SUIN-COIN", "SUIN");
    usdt = await Token.deploy("US-TEDDER", "USDT");

    const Factory = await ethers.getContractFactory("Factory", {
        libraries: {
            TickMath: tickMath.target,
            PoolHelper: poolHelper.target,
            SqrtPriceMath: sqrtPriceMath.target
        },
    });
    factory = await Factory.deploy();

    const Pool = await ethers.getContractFactory("Pool", {
        libraries: {
            // BitMath : bitMath.target,
            // PoolHelper: poolHelper.target,
            TickMath: tickMath.target,
            SqrtPriceMath: sqrtPriceMath.target,
            // TickBitmap : tickBitmap.target,
        },
    }); 

    const SwapRouter = await ethers.getContractFactory("SwapRouter");
    swapRouter = await SwapRouter.deploy(factory.target);


    sqrtPrice = Math.sqrt(1845.42);
    sqrtPriceX96 = getSqrtPriceX96FromSqrtPrice(sqrtPrice);

    const tx = await factory.createPool(suin.target, usdt.target, sqrtPriceX96);
    const receipt = await tx.wait();
    pool = await ethers.getContractAt("Pool", receipt.logs[0].args[2]);

    const NonfungiblePositionManager = await ethers.getContractFactory("NonfungiblePositionManager", {
        libraries: {
            TickMath: tickMath.target,
            PoolHelper: poolHelper.target,
            SqrtPriceMath: sqrtPriceMath.target
        },
    });

    nonfungiblePositionManager = await NonfungiblePositionManager.deploy(factory.target);


    [token0, token1, flag] = suin < usdt ? [suin, usdt, false] : [usdt, suin, true];
}

before(async function () {
    await deployFixture();
});


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

            it("Should fail if pool already exist for tokens", async function() {
                await expect(factory.createPool(suin.target, usdt.target, sqrtPriceX96)).to.be.reverted;
            })

            it("Should fail if pool already exist for reversed tokens", async function() {
                await expect(factory.createPool(usdt.target, suin.target, sqrtPriceX96)).to.be.reverted;
            })

            it("Should correctly map tokens to pool", async function () {
                const mappingAddr = await factory.getTokensToPool(suin.target, usdt.target);
                expect(mappingAddr).to.equal(pool.target);
            })
        })

        describe("Pool", async function () {
            it("Should set the right owner", async function () {
                expect(await pool.owner()).to.equal(await factory.getAddress());
            })
        })
    })
    

    describe("Mint Tokens", async function () {
        it("Shound correctly mint init 100/1 SUIN tokens to LP/Users", async function() {
            await suin.mint(LP, ethers.parseEther("100100"));
            await suin.mint(alice, ethers.parseEther("1"));
            await suin.mint(trump, ethers.parseEther("2"));
            expect(await suin.balanceOf(LP)).to.equal(ethers.parseEther("100100"));
            expect(await suin.balanceOf(alice)).to.equal(ethers.parseEther("1"));
        })

        it("Shound correctly mint init 10000/100 USDT tokens to LP/Users", async function() {
            await usdt.mint(LP, ethers.parseEther("18500100000"));
            await usdt.mint(bob, ethers.parseEther("1850"));
            expect(await usdt.balanceOf(LP)).to.equal(ethers.parseEther("18500100000"));
            expect(await usdt.balanceOf(bob)).to.equal(ethers.parseEther("1850"));
        })
    })

    describe("Liquidity", async function () {

        describe("Add Liquidity", async function () {
            async function addLiquidity(tickLower, tickUpper, amount0, amount1) {
                let sqrtPriceAX96 = await tickMath.getSqrtRatioAtTick(tickLower);
                let sqrtPriceBX96 = await tickMath.getSqrtRatioAtTick(tickUpper);
                // let sqrtPriceA = Number(sqrtPriceAX96) / Number(Q96);
                // let sqrtPriceB = Number(sqrtPriceBX96) / Number(Q96);
                let sqrtPriceA = Math.sqrt(1415.2195);
                let sqrtPriceB = Math.sqrt(2235.0459);
                let xx = Number(sqrtPriceBX96) * Number(sqrtPriceX96) / Number(sqrtPriceBX96 - sqrtPriceX96);
                let yy = Number(sqrtPriceX96 - sqrtPriceAX96) ;
                let x = (sqrtPriceB - sqrtPrice) / sqrtPriceB / sqrtPrice;
                let y = sqrtPrice - sqrtPriceA;
                let liquidity;
                
                let aa = (sqrtPrice - sqrtPriceA) * sqrtPriceB *  sqrtPrice / (sqrtPriceB - sqrtPrice);

                if(sqrtPriceX96 < sqrtPriceAX96) 
                    liquidity = await sqrtPriceMath.getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96 ,amount0);
                else if(sqrtPriceBX96 < sqrtPriceX96)
                    liquidity = await sqrtPriceMath.getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96 ,amount1);
                else{
                    
                    if(amount0 != 0)
                        liquidity = await sqrtPriceMath.getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96 ,amount0);
                    else
                        liquidity = await sqrtPriceMath.getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96 ,amount1);

                    amount1 = await sqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceBX96, liquidity);
                    // console.log(await sqrtPriceMath.getAmount0Delta(sqrtPriceX96, sqrtPriceBX96, liquidity));
                    // console.log(await sqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceX96, liquidity));
                }

                await suin.connect(LP).approve(nonfungiblePositionManager.target, amount0);
                await usdt.connect(LP).approve(nonfungiblePositionManager.target, amount1);

                let params = {
                    token0: suin,
                    token1: usdt,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: ethers.parseEther("0"),
                    amount1Min: ethers.parseEther("0"),
                    fee: 3,
                    to: LP,
                };

                let tx = await nonfungiblePositionManager.connect(LP).addLiquidity(params);
                let rec = await tx.wait();
                // tokenId
                let position = await nonfungiblePositionManager.getPosition(tokenId++);
                return [position.liquidity, liquidity, rec];
            }

            it("Should correctly add liquidity when lower <= price <= upper.", async function() {
                let ret = await addLiquidity(75207n, 75209n, ethers.parseEther("100000"), 0);
                // console.log(ret[2].logs[3].args);
                expect(ret[0]).to.equal(ret[1]);
            })

            it("Should correctly add liquidity when price < lower", async function() {
                let ret = await addLiquidity(76964n, 77164n, ethers.parseEther("5"), 0);
                expect(ret[0]).to.equal(ret[1]);
            })

            it("Should correctly add liquidity when upper < price ", async function() {
                let ret = await addLiquidity(74245n, 74568n, 0, ethers.parseEther("500"));
                expect(ret[0]).to.equal(ret[1]);
            })
        })

        describe("Remove Liquidity & Collect", async function() {
            100
            it("Should correctly remove liquidity & collect when lower <= price <= upper", async function() {
                // console.log(await tickMath.getTickAtSqrtRatio(getSqrtPriceX96FromSqrtPrice(Math.sqrt(1415.2195))));
                // console.log(await tickMath.getTickAtSqrtRatio(getSqrtPriceX96FromSqrtPrice(Math.sqrt(2235.0459))));
                let params = {
                    liquidity : (139009693081600816976061187898n / 2n),
                    tokenId : 1,
                    poolId : 1,
                    amount0Min : 0,
                    amount1Min : 0
                }

                let tx =  await nonfungiblePositionManager.connect(LP).removeLiquidity(params);
                let rec = await tx.wait();
                expect(scaling(rec.logs[0].args[3])).to.equal(scaling(412573771140880249437170404n / 2n));
                params = {
                    tokenId : 1,
                    to : LP
                }
                let balance = await suin.balanceOf(LP);

                tx = await nonfungiblePositionManager.connect(LP).collect(params);
                rec = await tx.wait();
                expect(rec.logs[2].args[1]).to.equal(LP);
                expect(scaling(rec.logs[2].args[2])).to.equal(scaling(await suin.balanceOf(LP) -  balance));
            })


            it("Should correctly remove liquidity & collect when upper < price", async function() {
                params = {
                    liquidity : 4713676098071137621473n,
                    tokenId : 2,
                    poolId : 1,
                    amount0Min : 0,
                    amount1Min : 0
                }

                let tx =  await nonfungiblePositionManager.connect(LP).removeLiquidity(params);
                let rec = await tx.wait();
                expect(scaling(rec.logs[0].args[2])).to.equal(1);
                
                params = {
                    tokenId : 2,
                    to : LP
                }
                let balance = await suin.balanceOf(LP);

                tx = await nonfungiblePositionManager.connect(LP).collect(params);
                rec = await tx.wait();
                expect(rec.logs[1].args[1]).to.equal(LP);
                expect((rec.logs[1].args[2])).to.equal( (await suin.balanceOf(LP) -  balance));
            })
        })
    })

    // 스왑
    describe("Swap", async function () {
        // * 추가 정렬 순서에 따른 swap test case 구현 
            it("Should correctly swap zero for one & exact input tokens", async function() {

                let amountIn = ethers.parseEther("1");
                params = {
                    tokenIn: suin.target,
                    tokenOut: usdt.target,
                    recipient: alice,
                    amountIn: amountIn,
                    amountOutMinimum: 0n,
                    sqrtPriceLimitX96 : 100n
                }
                // console.log(Math.pow(Number(await pool.getCurrentSqrtPriceX96()) / 2 ** 96, 2));

                await suin.connect(alice).approve(swapRouter.target, amountIn);
                await swapRouter.connect(alice).exactInput(params);

                // console.log(scaling(await suin.balanceOf(alice)), scaling(await usdt.balanceOf(alice)));
            }) 
            
            it("Shoult correctly swap one for zero & exact input tokens", async function() {
                let amountIn = ethers.parseEther("1850");
                params = {
                    tokenIn: usdt.target,
                    tokenOut: suin.target,
                    recipient: bob,
                    amountIn: amountIn,
                    amountOutMinimum: 0n,
                    sqrtPriceLimitX96 : sqrtPriceX96*2n
                }
                await usdt.connect(bob).approve(swapRouter.target, amountIn);
                await swapRouter.connect(bob).exactInput(params);
                // console.log(scaling(await suin.balanceOf(bob)), scaling(await usdt.balanceOf(bob)));
            })

            it("Should correctly swap zero for one & exact output tokens", async function() {

                let amountOut = ethers.parseEther("1845");
                params = {
                    tokenIn: suin.target,
                    tokenOut: usdt.target,
                    recipient: trump,
                    amountOut: amountOut,
                    amountInMaximum: ethers.parseEther("21232"),
                    sqrtPriceLimitX96 : 0n
                }

                await suin.connect(trump).approve(swapRouter.target, ethers.parseEther("2"));
                await swapRouter.connect(trump).exactOutput(params);
                // console.log(scaling(await suin.balanceOf(trump)), scaling(await usdt.balanceOf(trump)));
            }) 

            it("Should correctly swap one for zero & exact output tokens", async function() {

                let amountOut = ethers.parseEther("0.5");
                params = {
                    tokenIn: usdt.target,
                    tokenOut: suin.target,
                    recipient: trump,
                    amountOut: amountOut,
                    amountInMaximum: ethers.parseEther("21232"),
                    sqrtPriceLimitX96 : sqrtPriceX96 * 2n
                }

                await usdt.connect(trump).approve(swapRouter.target, ethers.parseEther("1200"));
                await swapRouter.connect(trump).exactOutput(params);
                // console.log(scaling(await suin.balanceOf(trump)), scaling(await usdt.balanceOf(trump)));
            }) 


    })

});