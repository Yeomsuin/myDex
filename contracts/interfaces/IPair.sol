// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IPair {
    function getReserves() external returns (uint _reserve0, uint _reserve1);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to) external;
}