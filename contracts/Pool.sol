// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IPool.sol";

contract Pool is IPool {
    address public immutable token0;
    address public immutable token1;
    address public immutable owner;
    uint private reserve0;
    uint private reserve1;
    uint private k; // etherReserve * reserve1 

    constructor(address _token0, address _token1) {
        (token0, token1) = (_token0, _token1);
        owner = msg.sender;
        reserve0 = 0;
        reserve1 = 0;
        k = 0;
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }


    function getReserves () public view returns (uint _reserve0, uint _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }


    function swap(uint amount0Out, uint amount1Out, address to) public {
        if(amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if(amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        require(reserve0 > amount0Out && reserve1 > amount1Out);

        uint amount0In = (balance0 > reserve0) ? (balance0 - reserve0) : 0;
        uint amount1In = (balance1 > reserve1) ? (balance1 - reserve1) : 0;

        require(amount0In > 0 || amount1In > 0);

        uint balance0WithFee = balance0 * 1000 - amount0In * 3;
        uint balance1WithFee = balance1 * 1000 - amount1In * 3;

        require(balance0WithFee * balance1WithFee >= reserve0 * reserve1 * 1000**2);
 
        _update(balance0, balance1);
    }
}