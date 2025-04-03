// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface ISwapCallBack {
    struct SwapCallbackData {
        address token0;
        address token1;
        address to;
    }

    function swapCallBack(address tokenIn, address tokenOut, int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}