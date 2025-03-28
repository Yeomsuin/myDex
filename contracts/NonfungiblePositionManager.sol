// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMintCallBack.sol";
import "./lib/PoolHelper.sol";
import "./lib/TickMath.sol";
import "./lib/SqrtPriceMath.sol";

contract NonfungiblePositionManager is ERC721, IMintCallBack{
    
    struct Positions {
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

    struct MintCallbackData {
        PoolInfo poolInfo;
        address to;
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        uint24 fee;
        address to;
    }

    // poolAddress -> poolId
    mapping(address => uint80) private _poolIds;
    
    // token Id -> position info
    mapping(uint256 => Positions) private _positions;
    
    // Position.PoolId -> PoolInfo
    mapping(uint80 => PoolInfo) private _poolIdToPoolInfo;
    uint176 private _nextId = 1;
    uint80 private _nextPoolId = 1;

    //   address private immutable _tokenDescriptor;

    address public factory;

    constructor(address _factory) ERC721('Uniswap Positions NFT', 'UNI-POS-NFT'){
        factory = _factory;
    }


   function mintCallBack( uint256 amount0, uint256 amount1, bytes calldata data) external override{
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        // callback validation
        require(msg.sender == PoolHelper.getPool(factory, decoded.poolInfo.token0, decoded.poolInfo.token1), 'Invalid sender');

        if (amount0 > 0) IERC20(decoded.poolInfo.token0).transferFrom(decoded.to, msg.sender, amount0);
        if (amount1 > 0) IERC20(decoded.poolInfo.token1).transferFrom(decoded.to, msg.sender, amount1);
    }

    /// @dev Caches a pool info
    function cachePoolInfo(address pool, PoolInfo memory poolInfo) private returns (uint80 poolId) {
        poolId = _poolIds[pool];
        if (poolId == 0) {
            _poolIds[pool] = (poolId = _nextPoolId++);
            _poolIdToPoolInfo[poolId] = poolInfo;
        }
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
        Positions memory positions = _positions[tokenId];
        require(positions.poolId != 0, 'Invalid token ID');
        PoolInfo memory poolInfo = _poolIdToPoolInfo[positions.poolId];
        return (
            positions.nonce,
            positions.operator,
            poolInfo.token0,
            poolInfo.token1,
            poolInfo.fee,
            positions.tickLower,
            positions.tickUpper,
            positions.liquidity,
            positions.feeGrowthInside0LastX128,
            positions.feeGrowthInside1LastX128,
            positions.tokensOwed0,
            positions.tokensOwed1
        );
    }


    // 남은 금액은 어차피 approve만 해놔서 잔돈 안 돌려줘도 됨.
    function addLiquidity(AddLiquidityParams calldata params) public returns (uint256 amount0, uint256 amount1, uint128 liquidity, uint256 tokenId){
        
        PoolInfo memory poolInfo = PoolInfo({token0: params.token0, token1: params.token1, fee: params.fee});

        IPool pool = IPool(PoolHelper.getPool(factory, params.token0, params.token1));        

        {
            uint160 sqrtPriceX96 = pool.getCurrentSqrtPriceX96();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            // tick이 음수인 경우 swap
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            if (sqrtPriceX96 <= sqrtRatioAX96) {
                liquidity = SqrtPriceMath.getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, params.amount0Desired);
            } 
            else if (sqrtPriceX96 < sqrtRatioBX96) {
                uint128 liquidity0 = SqrtPriceMath.getLiquidityForAmount0(sqrtPriceX96, sqrtRatioBX96, params.amount0Desired);
                uint128 liquidity1 = SqrtPriceMath.getLiquidityForAmount1(sqrtRatioAX96, sqrtPriceX96, params.amount1Desired);

                liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            } else {
                liquidity = SqrtPriceMath.getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, params.amount1Desired);
            }
        }

        (amount0, amount1) = pool.mint(params.tickLower, params.tickUpper, liquidity, abi.encode(MintCallbackData({poolInfo: poolInfo, to : msg.sender})));

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');

        _mint(params.to, (tokenId = _nextId++));

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.getPositions(params.tickLower, params.tickUpper);

        uint80 poolId = cachePoolInfo( address(pool), PoolInfo({token0: params.token0, token1: params.token1, fee: params.fee}));

         _positions[tokenId] = Positions({
            nonce: 0,
            operator: address(0),
            poolId: poolId,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: 0,
            tokensOwed1: 0
        });

        // event 발생
    }


    // 기존의 NFT에 Liquidity 추가하는 함수 = increaseLiquidity() 구현해야함.........


    // function removeLiquidity(address token0, address token1, uint liquidity, address to) public returns (uint amount0, uint amount1){
    //     (token0, token1) = PoolHelper.sortTokens(token0, token1);
    //     address pair = IFactory(factory).getTokensToPair(token0, token1);
    //     IERC20(pair).transferFrom(msg.sender, pair, liquidity);
    //     (amount0, amount1) = IPair(pair).burn(to);
    // }




  

}