// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IPool {
    function getReserves() external view returns (uint _reserve0, uint _reserve1);
    function swap(uint amount0Out, uint amount1Out, address to) external;
}