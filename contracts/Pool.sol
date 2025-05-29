// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/SqrtPriceMath.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import './lib/TickBitmap.sol';
import './interfaces/IMintCallBack.sol';
import "./interfaces/ISwapCallBack.sol";
import "./interfaces/IPool.sol";

contract Pool is IPool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(int24 => mapping(int24 => Position.Info));
    using Position for Position.Info;
    using TickBitmap for mapping(int16 => uint256);

    address public immutable token0;
    address public immutable token1;
    address public immutable owner;
    int24 public immutable tickSpacing = 1;
    uint256 constant Q128 = 0x100000000000000000000000000000000;

     struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        bool unlocked;
    }

    uint24 public fee;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    uint128 public liquidity;
    Slot0 public slot0;
    // [lowerTick][upperTick] => position.info
    mapping(int24 => mapping(int24 => Position.Info)) public positions;
    mapping(int24 => Tick.Info) public ticks;
    
    mapping(int16 => uint256) public tickBitmap;

    constructor(address _token0, address _token1, uint160 sqrtPriceX96) {
        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;
        fee = 3000;
        slot0 = Slot0({
         sqrtPriceX96 : sqrtPriceX96,
         tick : TickMath.getTickAtSqrtRatio(sqrtPriceX96),
         observationIndex : 0,
         observationCardinality : 0,
         observationCardinalityNext : 0,
         unlocked: true
        });
    }

    function _updatePosition(int24 tickLower, int24 tickUpper, int128 liquidityDelta, int24 tick) private returns(Position.Info storage position){
        
        position = positions[tickLower][tickUpper];

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; 

        bool flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false
            );

        bool flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true
            );

        if (flippedLower)  
            tickBitmap.flipTick(tickLower, tickSpacing);
        
        if (flippedUpper)  
            tickBitmap.flipTick(tickUpper, tickSpacing);
        
        // Position 안의 FeeGrowth 구하기 / 유동성 공급/제거로는 Fee는 변화가 없지만 최신화만
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        // Position Update
        position.update(liquidityDelta ,feeGrowthInside0X128, feeGrowthInside1X128);


        // 근데 유동성을 0이하로 빼면 어카냐?
        if(liquidityDelta < 0){
            if(flippedLower)
                ticks.clear(tickLower);
            if(flippedUpper)
                ticks.clear(tickUpper);
        }
    }

    function _modifyPosition(int24 tickLower, int24 tickUpper, int128 liquidityDelta) private returns(Position.Info storage position, int256 amount0, int256 amount1){
        require(tickLower < tickUpper, 'TLU');
        Slot0 memory _slot0 = slot0; 

        position = _updatePosition(tickLower, tickUpper, liquidityDelta, _slot0.tick);

        uint128 liquidityBefore = liquidity;

        if(liquidityDelta != 0){
            if(_slot0.tick < tickLower){
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta);
            }
            else if(_slot0.tick < tickUpper){
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta);
                
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    _slot0.sqrtPriceX96,
                    liquidityDelta);

                liquidity = liquidityDelta > 0 ? liquidityBefore + uint128(liquidityDelta) : liquidityBefore - uint128(-liquidityDelta);
            }
            else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidityDelta);
            }
        }
    }



    function mint(int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data) external override returns (uint256 amount0, uint256 amount1){

        // *수정 modify Position -> Liquidity update
         (, int256 amount0Int, int256 amount1Int) = _modifyPosition(tickLower, tickUpper, int128(amount));
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);
        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = IERC20(token0).balanceOf(address(this));
        if (amount1 > 0) balance1Before = IERC20(token1).balanceOf(address(this));

        IMintCallBack(msg.sender).mintCallBack(amount0, amount1, data);

        if (amount0 > 0) require(balance0Before + amount0 <= IERC20(token0).balanceOf(address(this)), 'M0');
        if (amount1 > 0) require(balance1Before + amount1 <= IERC20(token1).balanceOf(address(this)), 'M1');
        // event 발생
    }

    function burn(int24 tickLower, int24 tickUpper, uint128 amount) external override returns (uint256 amount0, uint256 amount1){
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(tickLower, tickUpper, -int128(amount));
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if(amount0 > 0 || amount1 > 0){
            position.tokensOwed0 += uint128(amount0);
            position.tokensOwed1 += uint128(amount1);
        }
    }

    function collect(address to, int24 tickLower, int24 tickUpper, uint128 amount0Requested,uint128 amount1Requested) external override returns (uint128 amount0, uint128 amount1){
        Position.Info storage position = positions[tickLower][tickUpper];

        // max
        amount0 = amount0Requested > position.tokensOwed0 ? amount0Requested : position.tokensOwed0;
        amount1 = amount1Requested > position.tokensOwed1 ? amount1Requested : position.tokensOwed1;
        
        if(amount0 > 0){
            position.tokensOwed0 -= amount0;
            IERC20(token0).transfer(to, amount0);
        }

        if(amount1 > 0){
            position.tokensOwed1 -= amount1;
            IERC20(token1).transfer(to, amount1);
        }

        // event 발생!!        
    }


    struct SwapCache {
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the current value of the tick accumulator, computed only if we cross an initialized tick
        int56 tickCumulative;
    }

     // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }


    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override  returns (int256 amount0, int256 amount1) {
     
        Slot0 memory slot0Start = slot0;

        require(slot0Start.unlocked);

        slot0Start.unlocked = false;

        bool exactIn = amountSpecified > 0;

        SwapCache memory cache = SwapCache({
            liquidityStart: liquidity,
            tickCumulative: 0
        });

        SwapState memory state = SwapState({
            amountSpecifiedRemaining : amountSpecified,
            amountCalculated : 0,
            sqrtPriceX96 : slot0Start.sqrtPriceX96,
            tick : slot0Start.tick,
            feeGrowthGlobalX128 : zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            liquidity : cache.liquidityStart
        });


        while(state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96){
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ?  step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96 
                    : step.sqrtPriceNextX96, 
                 state.liquidity,
                 state.amountSpecifiedRemaining,
                 fee    
            );

            if(exactIn){
                // + -> 0  : 남은 amountIn의 양
                state.amountSpecifiedRemaining -= int256(step.amountIn + step.feeAmount);
                // 0 -> - :  amountOut의 합
                state.amountCalculated -= int256(step.amountOut);
            }
            else{
                // - -> 0  : 남은 amountOut의 양
                state.amountSpecifiedRemaining += int256(step.amountOut);
                // 0 -> +  : amountIn의 합
                state.amountCalculated += int256(step.amountIn + step.feeAmount);
            }

            
            if(state.liquidity > 0) {
                state.feeGrowthGlobalX128 += Math.mulDiv(step.feeAmount, Q128, state.liquidity);
            }

            // Shift Tick if target price riched the next price
            if(state.sqrtPriceX96 == step.sqrtPriceNextX96){
                // bitmap init
                if(step.initialized){
                    int128 liquidityNet = ticks.cross(
                        step.tickNext,
                        zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128,
                        zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128
                    );

                    state.liquidity = zeroForOne ? state.liquidity - uint128(-liquidityNet) : state.liquidity + uint128(liquidityNet);
                }

                state.tick = zeroForOne ? state.tick - 1: state.tick;
            }
            else{
                // cross tick이 끝났을 때 || 안 변했을 때 tick update
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }

        }

        // slot0에 update
        if(state.tick != slot0Start.tick){
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
            slot0.tick = state.tick;
        }
        else{
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // liquidity Update
        if(cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        
        // Global Fee update
        if(zeroForOne){
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        }
        else{
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        // zeroForOne  1. A'-> B / 2. A -> B' / 2. B'->A / 1. B -> A'
        (amount0, amount1) = zeroForOne == exactIn
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);


        // transfer
        if(zeroForOne){
            if(amount1 < 0) IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = IERC20(token0).balanceOf(address(this));
            ISwapCallBack(msg.sender).swapCallBack(amount0, amount1, data);
            require(balance0Before + uint256(amount0) <= IERC20(token0).balanceOf(address(this)));
        }
        else{
            if(amount0 < 0) IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = IERC20(token1).balanceOf(address(this));
            ISwapCallBack(msg.sender).swapCallBack(amount0, amount1, data);
            require(balance1Before + uint256(amount1) <= IERC20(token1).balanceOf(address(this)));
        }

        slot0.unlocked = true;
    }

    function getCurrentSqrtPriceX96() external view override returns (uint160 sqrtPriceX96){
        sqrtPriceX96 = slot0.sqrtPriceX96;
    }

    function getPositions(int24 tickLower, int24 tickUpper) external view override returns ( uint128 _liquidity, uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1){

        Position.Info memory _pos = positions[tickLower][tickUpper];

        _liquidity = _pos.liquidity;
        feeGrowthInside0LastX128 = _pos.feeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = _pos.feeGrowthInside1LastX128;
        tokensOwed0 = _pos.tokensOwed0;
        tokensOwed1 = _pos.tokensOwed1;
    }
}