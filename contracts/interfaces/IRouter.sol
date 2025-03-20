pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRouter {
    function addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min, address to) external returns (uint finalAmount0, uint finalAmount1, uint liquidity);
}