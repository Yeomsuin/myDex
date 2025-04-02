const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers");
  const { expect } = require("chai");
const { ethers } = require("hardhat");
const { extendProvider } = require("hardhat/config");

let LP, alice, bob, suin, usdt, factory, pool, poolHelper, flag, token0, token1, position, sqrtPriceMath, tick, tickMath, nonfungiblePositionManager;
const decimals = ethers.parseEther("1");
const Q96 = 1n << 96n;
let sqrtPriceX96, sqrtPrice, tokenId = 1;

function scailing(amount) {
    return Number(amount) / Number(decimals);
}

function getSqrtPriceX96FromSqrtPrice(price) {
    return BigInt(price * Number(Q96)); 
}

async function deployFixture() {
    const [owner, LP, alice, bob] = await ethers.getSigners();

    // 수정해야 할수도
    const PoolHelper = await ethers.getContractFactory("PoolHelper");
    const poolHelper = await PoolHelper.deploy();
    const Tick = await ethers.getContractFactory("Tick");
    const tick = await Tick.deploy();
    const TickMath = await ethers.getContractFactory("TickMath");
    const tickMath = await TickMath.deploy();
    const SqrtPriceMath = await ethers.getContractFactory("SqrtPriceMath");
    const sqrtPriceMath = await SqrtPriceMath.deploy();
    const Position = await ethers.getContractFactory("Position");
    const position = await Position.deploy();
    

    const Token = await ethers.getContractFactory("Token");
    const suin = await Token.deploy("SUIN-COIN", "SUIN");
    const usdt = await Token.deploy("US-TEDDER", "USDT");

    const Factory = await ethers.getContractFactory("Factory", {
        libraries: {
            TickMath: tickMath.target,
            PoolHelper: poolHelper.target,
            SqrtPriceMath: sqrtPriceMath.target
        },
    });
    const factory = await Factory.deploy();

    const Pool = await ethers.getContractFactory("Pool", {
        libraries: {
            TickMath: tickMath.target,
            // PoolHelper: poolHelper.target,
            SqrtPriceMath: sqrtPriceMath.target
        },
    }); 
    let sqrtPrice = Math.sqrt(1845.42);
    let sqrtPriceX96 = getSqrtPriceX96FromSqrtPrice(sqrtPrice);

    const tx = await factory.createPool(suin.target, usdt.target, sqrtPriceX96);
    const receipt = await tx.wait();
    const pool = await ethers.getContractAt("Pool", receipt.logs[0].args[2]);

    const NonfungiblePositionManager = await ethers.getContractFactory("NonfungiblePositionManager", {
        libraries: {
            TickMath: tickMath.target,
            PoolHelper: poolHelper.target,
            SqrtPriceMath: sqrtPriceMath.target
        },
    });

    const nonfungiblePositionManager = await NonfungiblePositionManager.deploy(factory.target);


    [token0, token1, flag] = suin < usdt ? [suin, usdt, false] : [usdt, suin, true];
    return {sqrtPrice, sqrtPriceX96, owner, LP, alice, bob, suin, usdt, Token, factory, pool, nonfungiblePositionManager, flag, poolHelper, position, sqrtPriceMath, tick, tickMath};
}

before(async function () {
    ({ sqrtPrice, sqrtPriceX96, owner, LP, alice, bob, suin, usdt, Token, factory, pool, nonfungiblePositionManager, flag, poolHelper, position, sqrtPriceMath, tick, tickMath } = await deployFixture());
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
                let ret = await addLiquidity(72554n, 77124n, ethers.parseEther("1"), 0);
                expect(ret[0]).to.equal(ret[1]);
            })

            it("Should correctly add liquidity when price < lower", async function() {
                let ret = await addLiquidity(76964n, 77164n, ethers.parseEther("1"), 0);
                expect(ret[0]).to.equal(ret[1]);
            })

            it("Should correctly add liquidity when upper < price ", async function() {
                let ret = await addLiquidity(74245n, 74568n, 0, ethers.parseEther("1500"));
                expect(ret[0]).to.equal(ret[1]);
            })
        })

        describe("Remove Liquidity & Collect", async function() {
            
            it("Should correctly remove liquidity & collect when lower <= price <= upper", async function() {
                // console.log(await tickMath.getTickAtSqrtRatio(getSqrtPriceX96FromSqrtPrice(Math.sqrt(1415.2195))));
                // console.log(await tickMath.getTickAtSqrtRatio(getSqrtPriceX96FromSqrtPrice(Math.sqrt(2235.0459))));
                let params = {
                    liquidity : (470350844781244533593n / 2n),
                    tokenId : 1,
                    poolId : 1,
                    amount0Min : 0,
                    amount1Min : 0
                }

                let tx =  await nonfungiblePositionManager.connect(LP).removeLiquidity(params);
                let rec = await tx.wait();
                expect(scailing(rec.logs[0].args[3])).to.equal(scailing(2511202624581185400160n / 2n));
                params = {
                    tokenId : 1,
                    to : LP
                }
                let balance = await suin.balanceOf(LP);

                tx = await nonfungiblePositionManager.connect(LP).collect(params);
                rec = await tx.wait();
                expect(rec.logs[2].args[1]).to.equal(LP);
                expect(scailing(rec.logs[2].args[2])).to.equal(scailing(await suin.balanceOf(LP) -  balance));
            })


            it("Should correctly remove liquidity & collect when upper < price", async function() {
                let params = {
                    liquidity : 4713676098071137621473n,
                    tokenId : 2,
                    poolId : 1,
                    amount0Min : 0,
                    amount1Min : 0
                }

                let tx =  await nonfungiblePositionManager.connect(LP).removeLiquidity(params);
                let rec = await tx.wait();
                expect(scailing(rec.logs[0].args[2])).to.equal(1);
                
                params = {
                    tokenId : 2,
                    to : LP
                }
                let balance = await suin.balanceOf(LP);

                tx = await nonfungiblePositionManager.connect(LP).collect(params);
                rec = await tx.wait();
                expect(rec.logs[1].args[1]).to.equal(LP);
                expect(scailing(rec.logs[1].args[2])).to.equal( scailing(await suin.balanceOf(LP) -  balance));
            })
        })
    })
/*

    describe("Pricing", async function () {
        it("Should correctly calculate 'quote price'", async function() {
            const rx = ethers.parseEther("10000.0");
            const ry = ethers.parseEther("100.0");
            const x = ethers.parseEther("10.0");
            const amount =await poolHelper.quote(x, rx, ry);  
            const res = x * ry / rx;
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(res));
        })
    

        it("Should correctly calculate 'output price'", async function() {
            let [x, y] = await pool.getReserves();
            const dx = ethers.parseEther("2");
            [x, y] = flag ? [y, x] : [x, y];
            const amount = await poolHelper.getOutputAmount(factory, suin, usdt, dx); 
            const dxWithFee = dx * 997n;
            const dy = y * dxWithFee / (x * 1000n + dxWithFee);
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dy));
        })

        it("Should correctly calculate 'input price'", async function() {
            let [x, y] = await pool.getReserves();
            const dy = ethers.parseEther("10.0");
            [x, y] = flag ? [y, x] : [x, y];
            const amount = await poolHelper.getInputAmount(factory, suin, usdt, dy);
            const dx = x * dy / (y - dy) *  1000n / 997n + 1n;
            await expect(ethers.formatEther(amount)).to.equal(ethers.formatEther(dx));
        })
    
    })

    describe("Swap", async function () {

        // * 추가 정렬 순서에 따른 swap test case 구현 
            // 100, 10000
            it("Should correctly swap exact token-to-token by asc", async function() {
                let [reserve0, reserve1] = await pool.getReserves();
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
            //     let [reserve0, reserve1] = await pool.getReserves();
            //     let amountIn = "0.2";
            //     let amountOut = ethers.parseEther(amountIn) * 997n * reserve1 / (reserve0 * 1000n + ethers.parseEther(amountIn) * 997n);
            //     let beforeBalance = await suin.balanceOf(alice);
            //     await suin.connect(alice).approve(router.target, ethers.parseEther(amountIn));
            //     await router.connect(alice).swapExactTokenToToken(suin, usdt, ethers.parseEther(amountIn), 0, alice);
            //     expect(await suin.balanceOf(alice)).to.equal(beforeBalance - ethers.parseEther(amountIn));
            //     expect(await usdt.balanceOf(alice)).to.equal(amountOut);
            // }) 
    
    
            
            // it("Should correctly swap token-to-exact token by asc", async function() {
            //     let [reserve0, reserve1] = await pool.getReserves();
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
                let [reserve0, reserve1] = await pool.getReserves();
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

    */
});