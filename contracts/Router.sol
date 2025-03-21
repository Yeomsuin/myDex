// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IPair.sol";
import "./lib/library.sol";

contract Router is IRouter {
    address public immutable factory;

    constructor(address _factory){
        factory = _factory;
    }


    /**
     * @notice              Pair에 유동성을 공급하는 함수.
     * @param token0        token0의 Contract Address
     * @param token1        token1의 Contract Address
     * @param amount0       Liquidity Pool에 공급할 token0의 양
     * @param amount1       Liquidity Pool에 공급할 token1의 양
     * @param amount0Min    Slippage로 발생할 수 있는 손해의 최댓값 설정
     * @param amount1Min    Slippage로 발생할 수 있는 손해의 최댓값 설정
     */ 
    function _addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min) private returns (uint finalAmount0, uint finalAmount1){
        (token0, token1) = Library.sortTokens(token0, token1);
        (uint reserve0, uint reserve1) = Library.getReserves(factory, token0, token1);
        
        if(reserve0 == 0 && reserve1 == 0){
            (reserve0, reserve1) = (amount0, amount1);
        }
        else{
            uint calcAmount0 = Library.quote(amount1, reserve1, reserve0);
            
            // 슬리피지 제한(amount0Min) <= 계산된 양(calcAmount0) <= 주어진 양(amount0)
            if(calcAmount0 <= amount0) {
                require(calcAmount0 >= amount0Min, "Slippage Exceeded");
                (finalAmount0, finalAmount1) = (calcAmount0, amount1);  
            }
            else {
                uint calcAmount1 = Library.quote(amount0, reserve0, reserve1);
                if(calcAmount1 <= amount1){
                    require(calcAmount1 >= amount1Min, "Slippage Exceeded");
                    (finalAmount0, finalAmount1) = (amount0, calcAmount1);
                }
                else
                    revert();
            }
        }
    }

    // 남은 금액은 어차피 approve만 해놔서 잔돈 안 돌려줘도 됨. / user가 token amount의 권한을 Router에게 줌! 아하 모먼트 ㅋㅋㅋ
    function addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min, address to) public override returns (uint finalAmount0, uint finalAmount1, uint liquidity){
        (finalAmount0, finalAmount1) = _addLiquidity(token0, token1, amount0, amount1, amount0Min, amount1Min);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        IERC20(pair).transferFrom(msg.sender, pair, finalAmount0);
        IERC20(pair).transferFrom(msg.sender, pair, finalAmount1);
        liquidity = IPair(pair).mint(to);
    }


    function removeLiquidity(address token0, address token1, uint liquidity, uint amount0Min, uint amount1Min, address to) public returns (uint amount0, uint amount1){
        (token0, token1) = Library.sortTokens(token0, token1);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (amount0, amount1) = IPair(pair).burn(to);

        require(amount0 >= amount0Min && amount1 >= amount1Min);  
    }

    function swapExactTokenToToken(address token0, address token1, uint amountIn, uint amountOutMin, address to) public returns (uint amountOut){
        (token0, token1) = Library.sortTokens(token0, token1);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        (uint reserve0, uint reserve1) = IPair(pair).getReserves();
        amountOut = Library.getOutputAmount(amountIn, reserve0, reserve1);
        require(amountOut >= amountOutMin);

        IERC20(token0).transfer(pair, amountIn);
        IPair(pair).swap(0, amountOut, to);
    }

    function swapTokenToExactToken(address token0, address token1, uint amountOut, uint amountInMax, address to) public returns (uint amountIn){
        (token0, token1) = Library.sortTokens(token0, token1);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        (uint reserve0, uint reserve1) = IPair(pair).getReserves();
        amountIn = Library.getInputAmount(amountOut, reserve0, reserve1);
        require(amountIn <= amountInMax);

        IERC20(token0).transfer(pair, amountOut);
        IPair(pair).swap(amountIn, 0, to);
    }
}