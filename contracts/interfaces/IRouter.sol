// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IRouter {
    function addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min, address to) external returns (uint finalAmount0, uint finalAmount1, uint liquidity);
}