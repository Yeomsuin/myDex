// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./SqrtPriceMath.sol";
import "hardhat/console.sol";


library SwapMath {
    /// @notice Computes the result of swapping some amount in, or amount out, given the parameters of the swap
    /// @dev The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
    /// @param sqrtRatioCurrentX96 The current sqrt price of the pool
    /// @param sqrtRatioTargetX96 The price that cannot be exceeded, from which the direction of the swap is inferred
    /// @param liquidity The usable liquidity
    /// @param amountRemaining How much input or output amount is remaining to be swapped in/out
    /// @param feePips The fee taken from the input amount, expressed in hundredths of a bip
    /// @return sqrtRatioNextX96 The price after swapping the amount in/out, not to exceed the price target
    /// @return amountIn The amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return amountOut The amount to be received, of either token0 or token1, based on the direction of the swap
    /// @return feeAmount The amount of input that will be taken as a fee
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    ) 
        internal
        pure
        returns(
            uint160 sqrtRatioNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        bool exactIn = amountRemaining >= 0;

        // Swap 시 가격 변동 계산
        if(exactIn){
            // amountRemaining 중에 Fee를 제외한 amount
            // feePips : 1 bip = 1/100 * 1% = 1/1e4
            // 1e6 = bip의 백분율        
            // 수수료를 떼고 계산하는 이유는 Input Token에서 무조건 수수료를 떼기 때문이다.!
            uint256 amountRemainingLessFee = Math.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6); 
          
            amountIn = zeroForOne 
                ? SqrtPriceMath.getAmount0Delta(
                    sqrtRatioTargetX96, 
                    sqrtRatioCurrentX96,
                    liquidity,
                    true
                )
                : SqrtPriceMath.getAmount1Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioTargetX96,
                    liquidity,
                    true
                );

            // 다음 sqrtRatio 계산 / 이 경우 다음 틱으로 넘어가야 함.
            if(amountRemainingLessFee >= amountIn){
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            }
            else{
                // 현재 틱에서 가격 변경
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
            }
        }
        // exact out
        else{
            amountOut = zeroForOne 
                ? SqrtPriceMath.getAmount1Delta(
                    sqrtRatioTargetX96, 
                    sqrtRatioCurrentX96,
                    liquidity,  
                    false
                )
                : SqrtPriceMath.getAmount1Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioTargetX96,
                    liquidity,
                    false
                );

            if(uint256(-amountRemaining) >= amountOut){
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            }
            else{
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
            }
        }   

        // Cross-tick swap인 경우 체크
        bool cross = sqrtRatioTargetX96  == sqrtRatioNextX96;

        // 고정 안된 토큰 amount 계산
        // 경우의 수 :  zeroForOne / max / exact -> 8개
        if(zeroForOne){
            // A' -> B 
            amountIn = cross && exactIn 
                ? amountIn 
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true); 

            // A -> B'
            amountOut = cross && !exactIn 
                ? amountOut 
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        }
        else{
            // B' -> A
            amountIn = cross && exactIn 
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            
            // B -> A'
            amountOut = cross && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // A -> B' || B -> A' --> amountRemaining < 0 인 경우
        // exactIn인 경우 input 고정이니까 exactOut인 경우 && 넘치는 경우만 고려
        if(!exactIn && amountOut > uint256(-amountRemaining))
            amountOut = uint256(-amountRemaining);

        // A' -> B || B' -> A && !cross인 경우 ?
        // sqrtRatioCurrentX96 == sqrtRatioNextX96;
        if(exactIn && !cross) {
            feeAmount = uint256(amountRemaining) - amountIn;
        }
        else{
            feeAmount = SqrtPriceMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}