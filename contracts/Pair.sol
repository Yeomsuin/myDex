// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/utils/math/Math.sol";
import "./interfaces/IPair.sol";

contract Pair is ERC20, IPair {

    address public immutable token0;
    address public immutable token1;
    address public immutable owner;
    uint private reserve0;
    uint private reserve1;
    uint private k; // etherReserve * reserve1 

    constructor(address _token0, address _token1) ERC20("Uniswap LP", "UNI-LP") {
        (token0, token1) = (_token0, _token1);
        owner = msg.sender;
        reserve0 = 100*10**18;
        reserve1 = 100*10**18;
        k = reserve0 * reserve1;
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }


    /**
     * @notice Output Token의 Amount를 고정하고 Input의 양을 수수료를 포함하여 결정하는 함수. 결정식은 다음과 같다.
     * dx = x * dy / (y - dy) * 0.997 (fee 0.03%)
     * @param outputAmount Swap할 Output Amount를 받는다.
     * @return OutputAmount에 대한 InputAmount를 계산한 값을 반환한다.
     */
    function getInputAmount(uint outputAmount, uint inputReserve, uint outputReserve) public view returns (uint) {
        uint inputAmount = reserve0 * outputAmount / (reserve1 - outputAmount);
        return inputAmount * 1000 / 997;
    }

    /**
     * @notice etherToTokenSwapWithFixedInput()에서 호출되며 수량 결정 수식은 다음과 같다.
     * dy = y * dx / (x + dx) * 997 / 1000
     * @param inputAmount Swap할 Input Amount를 받는다. 
     * @return InputAmount에 대한 OutputAmount를 계산한 값을 반환한다.
     */
    function getOutputAmount(uint inputAmount) public view returns (uint){
        uint outputAmount = reserve1 * inputAmount / (reserve0 + inputAmount);
        return outputAmount * 997 / 1000;
    }


    function mint(address to) public returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        
        uint totalSupply = totalSupply();

        uint amount0 = balance0 - reserve0;
        uint amount1 = balance1 - reserve1;

        // governance token에 대한 Fee *추가 

        if(totalSupply == 0){
            liquidity = Math.sqrt(amount0 * amount1);
            // Vault Infletion attack 방지를 위한 minLiquidity 소각 *추가 해야함.
        }
        else{
            // LP의 지분(amount0 / reserve0) * 발행량(totalSupply)
            liquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
        }

        require(liquidity > 0 );
        _mint(to, liquidity);

        _update(balance0, balance1);
        k = reserve0 * reserve1;
    }

    function burn(address to) public returns (uint amount0, uint amount1){
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint totalSupply = totalSupply();

        uint liquidity = balanceOf(address(this));

        amount0 = liquidity * balance0 / totalSupply;
        amount1 = liquidity * balance1 / totalSupply;

        _burn(address(this), liquidity); 
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);
        k = reserve0 * reserve1;
    }
 
    function getReserves () public view returns (uint _reserve0, uint _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function swap(uint amount0Out, uint amount1Out, address to) public {
    }
}