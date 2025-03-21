// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../interfaces/IFactory.sol";
import "../interfaces/IPair.sol";

library Library {

    function quote(uint amount0, uint reserve0, uint reserve1) pure public returns (uint amount1) {
        amount1 = amount0 * reserve1 / reserve0;
    }    

    function sortTokens(address token0, address token1) pure public returns (address tokenA, address tokenB){
        require(token0 != token1);
        (tokenA, tokenB) = (token0 < token1) ? (token0, token1) : (token1, token0);
        require(tokenA != address(0));
    }

    function getReserves(address factory, address token0, address token1) public returns (uint reserve0, uint reserve1) {
        address _pair = getPair(factory, token0, token1);
        (reserve0, reserve1) = IPair(_pair).getReserves();
    }

    
    // factory -> token0/1의 주소로 -> Pair의 Address를 받아옴
    function getPair(address factory, address token0, address token1) public returns (address pair){
        pair = IFactory(factory).getTokensToPair(token0, token1);
    }

    function getOutputAmount(uint amountIn, uint reserve0, uint reserve1) public pure returns (uint amountOut){
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserve1;
        uint denominator = reserve0 * 1000 + amountInWithFee;
        
        amountOut = numerator / denominator;
    }

    function getInputAmount(uint amountOut, uint reserve0, uint reserve1) public pure returns (uint amountIn){
        uint numerator = reserve0 * amountOut * 1000;
        uint denominator = (reserve1 - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }
}


