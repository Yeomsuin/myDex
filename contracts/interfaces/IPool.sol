// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../lib/Position.sol";

interface IPool {
    function positions(int24 tickLower, int24 tickUpper) external view 
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
    );
    function getReserves() external view returns (uint _reserve0, uint _reserve1);
    function getCurrentSqrtPriceX96() external view returns (uint160 sqrtPriceX96);
    function mint(address to, int24 tickLower, int24 tickUpper, uint128 liquidity, bytes calldata data) external returns (uint256 amount0, uint256 amount1);
    function swap(uint amount0Out, uint amount1Out, address to) external;
}