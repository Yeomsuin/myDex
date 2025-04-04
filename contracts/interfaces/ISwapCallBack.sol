// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface ISwapCallBack {
    struct SwapCallbackData {
        address tokenIn;
        address tokenOut;
        address to;
    }

    function swapCallBack(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}