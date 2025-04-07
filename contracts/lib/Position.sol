// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title Position
/// @notice Positions represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Positions store additional state for tracking fees owed to the position
library Position {
    // info stored for each user's position
    struct Info {
        // the amount of liquidity owned by this position
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }
   
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    /// @notice Returns the Info struct of a position, given an owner and position boundaries
    /// @param self The mapping containing all user positions
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @return position The position info struct of the given owners' position
    function get(
        mapping(int24 => mapping(int24 => Info)) storage self,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[tickLower][tickUpper];
    }

    /// @notice Credits accumulated fees to a user's position
    /// @param self The individual position to update
    /// @param liquidityDelta The change in pool liquidity as a result of the position update
    /// @param feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @param feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {

        // gas optimization
        Info memory _self = self;

        uint128 liquidityNext;
        liquidityNext = liquidityDelta > 0 ? (_self.liquidity + uint128(liquidityDelta)) : (_self.liquidity  - uint128(-liquidityDelta));

        // calculate accumulated fees 
        // fee는 유동성으로 나누어져 저장 되어 있기 때문에 Liquidity를 곱한다.
        uint128 tokensOwed0  = uint128((feeGrowthInside0X128 - _self.feeGrowthInside0LastX128 ) * _self.liquidity / Q128);
        uint128 tokensOwed1  = uint128((feeGrowthInside1X128 - _self.feeGrowthInside1LastX128 ) * _self.liquidity / Q128);

        // update the position
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}