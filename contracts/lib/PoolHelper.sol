// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../interfaces/IFactory.sol";
import "../interfaces/IPool.sol";
import "hardhat/console.sol";

library PoolHelper {

    function quote(uint amount0, uint reserve0, uint reserve1) pure public returns (uint amount1) {
        amount1 = amount0 * reserve1 / reserve0;
    }    

    function sortTokens(address token0, address token1) pure public returns (address tokenA, address tokenB){
        require(token0 != token1);
        (tokenA, tokenB) = (token0 < token1) ? (token0, token1) : (token1, token0);
        require(tokenA != address(0));
    }

    // factory -> token0/1의 주소로 -> Pair의 Address를 받아옴
    function getPool(address factory, address token0, address token1) public view returns (address pair){
        pair = IFactory(factory).getTokensToPool(token0, token1);
    }
}


