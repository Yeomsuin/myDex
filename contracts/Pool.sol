// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import './interfaces/IMintCallback.sol';
import "./interfaces/IPool.sol";

contract Pool is IPool {
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
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    struct Position {
          // the amount of liquidity owned by this position
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }


    Slot0 public slot0;
    // [lowerTick][upperTick] => position
    mapping(int24 => mapping(int24 => Position)) public positions;

    constructor(address _token0, address _token1) {
        (token0, token1) = (_token0, _token1);
        owner = msg.sender;
        reserve0 = 0;
        reserve1 = 0;
        k = 0;
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }




    function mint( address to, int24 tickLower, int24 tickUpper, uint128 liquidity, bytes calldata data) external returns (uint256 amount0, uint256 amount1){

        // *수정 modify Position -> Liquidity update
        /*
         (, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int256(amount).toInt128()
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);
        */

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = IERC20(token0).balanceOf(address(this));
        if (amount1 > 0) balance1Before = IERC20(token1).balanceOf(address(this));

        IMintCallBack(msg.sender).mintCallBack(amount0, amount1, data);

        if (amount0 > 0) require(balance0Before + amount0 <= IERC20(token0).balanceOf(address(this)), 'M0');
        if (amount1 > 0) require(balance1Before + amount1 <= IERC20(token1).balanceOf(address(this)), 'M1');

        // event 발생
    }


    function swap(uint amount0Out, uint amount1Out, address to) public {
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


    function getReserves () public view returns (uint _reserve0, uint _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }


    function getPositions(int24 _tickLower, int24 _tickUpper) external view returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1){
        Position memory position = positions[_tickLower][_tickUpper];
        liquidity = position.liquidity;
        feeGrowthInside0LastX128 = position.feeGrowthInside0LastX128;
        feeGrowthInside1LastX128 = position.feeGrowthInside1LastX128;
        tokensOwed0 = position.tokensOwed0;
        tokensOwed1 = position.tokensOwed1;
    }

    function getCurrentSqrtPriceX96() external view returns (uint160 sqrtPriceX96){
        sqrtPriceX96 = slot0.sqrtPriceX96;
    }
}