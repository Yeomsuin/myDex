// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IFactory {
    function getTokensToPair(address token0, address token1) external view returns(address pair);
}