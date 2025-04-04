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

    function swapCallBack(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external override {
        // (bool exactInput, uint256 amountToPay) = amount0Delta > 0 ? (t  )
        require(amount0Delta > 0 || amount1Delta > 0);

        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));


        (bool exactIn, uint256 amountToPay) = 
            amount0Delta > 0 
                ? (data.tokenIn < data.tokenOut , uint256(amount0Delta))
                : (data.tokenIn > data.tokenOut, uint256(amount1Delta));    


        if(exactIn){
            IERC20(data.tokenIn).transferFrom(data.to, msg.sender, amountToPay);
        }
        else{
            data.tokenIn = data.tokenOut;
            IERC20(data.tokenIn).transferFrom(data.to, msg.sender, amountToPay);
        }
    }   


    function exactInput(ExactInputParams calldata params) external override payable returns(uint256 amountOut) {
        address pool = IFactory(factory).getTokensToPool(params.tokenIn, params.tokenOut);

        /*
            True(0 For 1) : 정상적인 상황
             <----- tick 
            False(1 For 0) : 뒤집어서 들어옴
                    tick ------>
        */
        bool zeroForOne = params.tokenIn < params.tokenOut; 

        (int256 amount0, int256 amount1) = IPool(pool).swap(
            params.recipient, 
            zeroForOne, 
            int256(params.amountIn), 
            params.sqrtPriceLimitX96, 
            abi.encode(SwapCallbackData({tokenIn: params.tokenIn, tokenOut: params.tokenOut, to: params.recipient}))
            );

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));

        require(amountOut >= params.amountOutMinimum);
    }


    function exactOutput(ExactOutputParams calldata params) external override payable returns(uint256 amountIn) {
        address pool = IFactory(factory).getTokensToPool(params.tokenIn, params.tokenOut);

        /*
            True(0 For 1) : 정상적인 상황
             <----- tick 
            False(1 For 0) : 뒤집어서 들어옴
                    tick ------>
        */
        bool zeroForOne = params.tokenIn < params.tokenOut; 

        (int256 amount0, int256 amount1) = IPool(pool).swap(
            params.recipient, 
            zeroForOne, 
            -int256(params.amountOut), 
            params.sqrtPriceLimitX96, 
            abi.encode(SwapCallbackData({tokenIn: params.tokenIn, tokenOut: params.tokenOut, to: params.recipient}))
            );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
                ? (uint256(amount0), uint256(-amount1))
                : (uint256(amount1), uint256(-amount0));

        require(amountIn <= params.amountInMaximum);
    }
}