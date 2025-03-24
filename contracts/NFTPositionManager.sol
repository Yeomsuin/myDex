// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/utils.sol";
import "./Pool.sol";

contract NFTPositionManager is ERC721{
        struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
       uint256 feeGrowthInside0LastX128;
       uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct PoolInfo {
        address token0;
        address token1;
        uint24 fee;
    }


    mapping(address => uint80) private _poolIds;
    
    
    // token Id -> position info
    mapping(uint256 => Position) private _positions;
    // Position.PoolId -> PoolInfo
    mapping(uint80 => PoolInfo) private _poolIdToPoolInfo;
    uint176 private _nextId = 1;
    //   address private immutable _tokenDescriptor;

    address public factory;


    constructor(address _factory) ERC721('Uniswap Positions NFT', 'UNI-POS-NFT'){
        factory = _factory;
    }
    
    function getPosition(uint256 tokenId) external view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        require(position.poolId != 0, 'Invalid token ID');
        PoolInfo memory poolInfo = _poolIdToPoolInfo[position.poolId];
        return (
            position.nonce,
            position.operator,
            poolInfo.token0,
            poolInfo.token1,
            poolInfo.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
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
    function _addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min) private view returns (uint finalAmount0, uint finalAmount1){
        (uint reserve0, uint reserve1) = Library.getReserves(factory, token0, token1);

        if(reserve0 == 0 && reserve1 == 0){
            (finalAmount0, finalAmount1) = (amount0, amount1);
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

    // 남은 금액은 어차피 approve만 해놔서 잔돈 안 돌려줘도 됨.
    function addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min, address to) public returns (uint finalAmount0, uint finalAmount1, uint liquidity){
        (finalAmount0, finalAmount1) = _addLiquidity(token0, token1, amount0, amount1, amount0Min, amount1Min);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        IERC20(token0).transferFrom(msg.sender, pair, finalAmount0);
        IERC20(token1).transferFrom(msg.sender, pair, finalAmount1);
        liquidity = IPair(pair).mint(to);
    }


    function removeLiquidity(address token0, address token1, uint liquidity, address to) public returns (uint amount0, uint amount1){
        (token0, token1) = Library.sortTokens(token0, token1);
        address pair = IFactory(factory).getTokensToPair(token0, token1);
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (amount0, amount1) = IPair(pair).burn(to);
    }

}