// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IPool.sol";
import "./lib/PoolHelper.sol";

contract SwapRouter is ISwapRouter {
    address public immutable factory;

    constructor(address _factory){
        factory = _factory;
    }

    function swapExactTokenToToken(address token0, address token1, uint amountIn, uint amountOutMin, address to) public returns (uint amountOut){
        (address tokenA,) = PoolHelper.sortTokens(token0, token1);
        address pool = IFactory(factory).getTokensToPool(token0, token1);
        amountOut = PoolHelper.getOutputAmount(factory, token0, token1, amountIn);
        require(amountOut >= amountOutMin);
        (uint amount0Out, uint amount1Out) = tokenA == token0 ?  (uint(0), amountOut) : (amountOut, uint(0));
        IERC20(token0).transferFrom(msg.sender, pool, amountIn);
        IPool(pool).swap(amount0Out, amount1Out, to);
    }

    function swapTokenToExactToken(address token0, address token1, uint amountOut, uint amountInMax, address to) public returns (uint amountIn){
        (address tokenA,) = PoolHelper.sortTokens(token0, token1);
        address pool = IFactory(factory).getTokensToPool(token0, token1);
        amountIn = PoolHelper.getInputAmount(factory, token0, token1, amountOut);

        require(amountIn <= amountInMax);

        (uint amount0Out, uint amount1Out) = tokenA == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
        
        IERC20(token0).transferFrom(msg.sender, pool, amountIn);
        IPool(pool).swap(amount0Out, amount1Out, to);
    }
}