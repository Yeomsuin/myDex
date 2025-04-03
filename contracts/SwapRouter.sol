// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ISwapCallBack.sol";
import "./interfaces/IPool.sol";
import "./lib/PoolHelper.sol";

contract SwapRouter is ISwapRouter, ISwapCallBack {
    address public immutable factory;

    constructor(address _factory){
        factory = _factory;
    }

    function swapCallBack(address tokenIn, address tokenOut, int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        // (bool exactInput, uint256 amountToPay) = amount0Delta > 0 ? (t  )
    }   


    function exactInput(ExactInputParams calldata params) external override payable returns(uint256 amountOut) {
        address pool = IFactory(factory).getTokensToPool(params.tokenIn, params.tokenOut);

        /*
            True(0 For 1) : 정상적인 상황
                   tick ----->

            False(1 For 0) : 뒤집어서 들어옴
            <----- tick
        */
        bool zeroForOne = params.tokenIn < params.tokenOut; 

        (int256 amount0, int256 amount1) = IPool(pool).swap(params.recipient, zeroForOne, int256(params.amountIn), params.sqrtPriceLimitX96, abi.encode(SwapCallbackData({token0: params.tokenIn, token1: params.tokenOut, to: params.recipient})));

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));

        require(amountOut >= params.amountOutMinimum);
    }


    // function swapExactTokenToToken(address token0, address token1, uint amountIn, uint amountOutMin, address to) public returns (uint amountOut){
    //     (address tokenA,) = PoolHelper.sortTokens(token0, token1);
    //     address pool = IFactory(factory).getTokensToPool(token0, token1);
    //     amountOut = PoolHelper.getOutputAmount(factory, token0, token1, amountIn);
    //     require(amountOut >= amountOutMin);
    //     (uint amount0Out, uint amount1Out) = tokenA == token0 ?  (uint(0), amountOut) : (amountOut, uint(0));
    //     IERC20(token0).transferFrom(msg.sender, pool, amountIn);
    //     IPool(pool).swap(amount0Out, amount1Out, to);
    // }

    // function swapTokenToExactToken(address token0, address token1, uint amountOut, uint amountInMax, address to) public returns (uint amountIn){
    //     (address tokenA,) = PoolHelper.sortTokens(token0, token1);
    //     address pool = IFactory(factory).getTokensToPool(token0, token1);
    //     amountIn = PoolHelper.getInputAmount(factory, token0, token1, amountOut);

    //     require(amountIn <= amountInMax);

    //     (uint amount0Out, uint amount1Out) = tokenA == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
        
    //     IERC20(token0).transferFrom(msg.sender, pool, amountIn);
    //     IPool(pool).swap(amount0Out, amount1Out, to);
    // }
}