// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface ISwapRouter {
    struct ExactInputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInput(ExactInputParams calldata params) external payable returns(uint256 amountOut);
}