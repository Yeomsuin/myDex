// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMintCallBack.sol";
import "./lib/utils.sol";
import "./lib/TickMath.sol";

contract NonfungiblePositionManager is ERC721, IMintCallBack{
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

    struct MintCallbackData {
        PoolInfo poolInfo;
        address to;
    }

    // poolAddress -> poolId
    mapping(address => uint80) private _poolIds;
    
    // token Id -> position info
    mapping(uint256 => Position) private _positions;
    
    // Position.PoolId -> PoolInfo
    mapping(uint80 => PoolInfo) private _poolIdToPoolInfo;
    uint176 private _nextId = 1;
    uint80 private _nextPoolId = 1;

    //   address private immutable _tokenDescriptor;

    address public factory;
    uint256 constant Q96 = 0x1000000000000000000000000;

    constructor(address _factory) ERC721('Uniswap Positions NFT', 'UNI-POS-NFT'){
        factory = _factory;
    }


   function mintCallBack( uint256 amount0, uint256 amount1, bytes calldata data) external {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        // callback validation
        require(msg.sender == Library.getPool(factory, decoded.poolInfo.token0, decoded.poolInfo.token1), 'Invalid sender');

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
    // function _addLiquidity(address token0, address token1, uint amount0, uint amount1, uint amount0Min, uint amount1Min) private view returns (uint finalAmount0, uint finalAmount1){
    //     (uint reserve0, uint reserve1) = Library.getReserves(factory, token0, token1);

    //     if(reserve0 == 0 && reserve1 == 0){
    //         (finalAmount0, finalAmount1) = (amount0, amount1);
    //     }
    //     else{
    //         uint calcAmount0 = Library.quote(amount1, reserve1, reserve0);
            
    //         // 슬리피지 제한(amount0Min) <= 계산된 양(calcAmount0) <= 주어진 양(amount0)
    //         if(calcAmount0 <= amount0) {
    //             require(calcAmount0 >= amount0Min, "Slippage Exceeded");
    //             (finalAmount0, finalAmount1) = (calcAmount0, amount1);  
    //         }
    //         else {
    //             uint calcAmount1 = Library.quote(amount0, reserve0, reserve1);
    //             if(calcAmount1 <= amount1){
    //                 require(calcAmount1 >= amount1Min, "Slippage Exceeded");
    //                 (finalAmount0, finalAmount1) = (amount0, calcAmount1);
    //             }
    //             else
    //                 revert();
    //         }
    //     }
    // }

    
    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = sqrtRatioAX96 * sqrtRatioBX96 / Q96;
        return uint128((amount0 * intermediate / (sqrtRatioBX96 - sqrtRatioAX96)));
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return uint128((amount1 * Q96 /  (sqrtRatioBX96 - sqrtRatioAX96)));
    }

    // 남은 금액은 어차피 approve만 해놔서 잔돈 안 돌려줘도 됨.
    function addLiquidity(address token0, address token1, int24 tickLower, int24 tickUpper, uint amount0Desired, uint amount1Desired, uint amount0Min, uint amount1Min, uint24 fee, address to) public returns (uint256 amount0, uint256 amount1, uint128 liquidity, uint256 tokenId){
        
        PoolInfo memory poolInfo = PoolInfo({token0: token0, token1: token1, fee: fee});

        IPool pool = IPool(Library.getPool(factory, token0, token1));        

        {
            uint160 sqrtPriceX96 = pool.getCurrentSqrtPriceX96();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            // tick이 음수인 경우 swap
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            if (sqrtPriceX96 <= sqrtRatioAX96) {
                liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0Desired);
            } 
            else if (sqrtPriceX96 < sqrtRatioBX96) {
                uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtRatioBX96, amount0Desired);
                uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtPriceX96, amount1Desired);

                liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            } else {
                liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1Desired);
            }
        }

        (amount0, amount1) = pool.mint(to, tickLower, tickUpper, liquidity, abi.encode(MintCallbackData({poolInfo: poolInfo, to : msg.sender})));

        require(amount0 >= amount0Min && amount1 >= amount1Min, 'Price slippage check');

        _mint(to, (tokenId = _nextId++));

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) = pool.getPositions(tickLower, tickUpper);

        uint80 poolId = cachePoolInfo( address(pool), PoolInfo({token0: token0, token1: token1, fee: fee}));

         _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: poolId,
            tickLower: tickLower,
            tickUpper: tickUpper,
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
    //     (token0, token1) = Library.sortTokens(token0, token1);
    //     address pair = IFactory(factory).getTokensToPair(token0, token1);
    //     IERC20(pair).transferFrom(msg.sender, pair, liquidity);
    //     (amount0, amount1) = IPair(pair).burn(to);
    // }

}