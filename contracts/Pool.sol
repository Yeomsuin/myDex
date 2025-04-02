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
import './interfaces/IMintCallBack.sol';
import "./interfaces/IPool.sol";

contract Pool is IPool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(int24 => mapping(int24 => Position.Info));
    using Position for Position.Info;
    address public immutable token0;
    address public immutable token1;
    address public immutable owner;
    uint private reserve0;
    uint private reserve1;
    uint private k; // etherReserve * reserve1

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
    }

    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    uint128 public liquidity;
    Slot0 public slot0;
    // [lowerTick][upperTick] => position.info
    mapping(int24 => mapping(int24 => Position.Info)) public positions;
    mapping(int24 => Tick.Info) public ticks;

    constructor(address _token0, address _token1, uint160 sqrtPriceX96) {
        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;
        slot0 = Slot0({
         sqrtPriceX96 : sqrtPriceX96,
         tick : TickMath.getTickAtSqrtRatio(sqrtPriceX96),
         observationIndex : 0,
         observationCardinality : 0,
         observationCardinalityNext : 0
        });
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
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
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true
            );

        // * tickBitmap 구현 시 추가
        // if (flippedLower)  tickBitmap.flipTick(tickLower, tickSpacing);
        
        // if (flippedUpper)  tickBitmap.flipTick(tickUpper, tickSpacing);
        
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




    function swap(uint amount0Out, uint amount1Out, address to) public override {
        if(amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if(amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        require(reserve0 > amount0Out && reserve1 > amount1Out);

        uint amount0In = (balance0 > reserve0) ? (balance0 - reserve0) : 0;
        uint amount1In = (balance1 > reserve1) ? (balance1 - reserve1) : 0;

        require(amount0In > 0 || amount1In > 0);

        uint balance0WithFee = balance0 * 1000 - amount0In * 3;
        uint balance1WithFee = balance1 * 1000 - amount1In * 3;

        require(balance0WithFee * balance1WithFee >= reserve0 * reserve1 * 1000**2);
 
        _update(balance0, balance1);
    }


    function getReserves () public view override returns (uint _reserve0, uint _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
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