// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public tokenAddress;
    address public owner;
    uint private ethReserve;
    uint private tokenReserve;
    uint private k; // etherReserve * tokenReserve 

    constructor(address _addr) ERC20("Uniswap LP", "UNI-LP") {
        tokenAddress = _addr;
        owner = msg.sender;
        ethReserve = 100*10**18;
        tokenReserve = 100*10**18;
        k = ethReserve * tokenReserve;
    }

    /**
     * @notice Output Token의 Amount를 고정하고 Input의 양을 수수료를 포함하여 결정하는 함수. 결정식은 다음과 같다.
     * dx = x * dy / (y - dy) * 0.997 (fee 0.03%)
     * @param outputAmount Swap할 Output Amount를 받는다.
     * @return OutputAmount에 대한 InputAmount를 계산한 값을 반환한다.
     */
    function getInputAmount(uint outputAmount) public view returns (uint) {
        uint inputAmount = ethReserve * outputAmount / (tokenReserve - outputAmount);
        return inputAmount * 1000 / 997;
    }

    /**
     * @notice etherToTokenSwapWithFixedInput()에서 호출되며 수량 결정 수식은 다음과 같다.
     * dy = y * dx / (x + dx) * 997 / 1000
     * @param inputAmount Swap할 Input Amount를 받는다. 
     * @return InputAmount에 대한 OutputAmount를 계산한 값을 반환한다.
     */
    function getOutputAmount(uint inputAmount) public view returns (uint){
        uint outputAmount = tokenReserve * inputAmount / (ethReserve + inputAmount);
        return outputAmount * 997 / 1000;
    }


    /**
     * @notice ETH->Token / Eth의 Amount를 고정하고 Output Token의 양을 조절하여 Swap하는 함수. 수수료 역시 Output에서 땐다. 
     * @param minTokens 과도한 slippage를 방지하기 위해 사용자가 허용 slippage를 Output Token의 수량으로 제어할 수 있다.
     */
    function etherToTokenSwapWithFixedInput(uint minTokens) public payable {
        uint etherAmount = msg.value;
        uint tokenAmount = getOutputAmount(etherAmount);
        require(tokenAmount >= minTokens);
        
        ERC20 token = ERC20(tokenAddress);
        token.transfer(msg.sender, tokenAmount);
    }


    /**
     * @notice ETH->Token / Output Token Amount를 고정하고 Eth의 양을 조절하여 Swap하는 함수. 수수료는 Eth에서 땐다. User가 Eth를 넉넉하게 보내야 함?? 
     * @param _tokenAmount Swap에 사용할 Token의 양을 받는다. User가 Approve 후, 수량을 parameter로 전달한다.
     * @param maxTokens 과도한 slippage를 방지하기 위해 사용자가 허용 slippage를 Eth 사용 수량으로 제어할 수 있다.
     */
    function etherToTokenSwapWithFixedOutput(uint _tokenAmount, uint maxTokens) public payable {
        uint tokenAmount = _tokenAmount;
        uint etherAmount = getInputAmount(tokenAmount);

        require(msg.value >= etherAmount);
        require(etherAmount <= maxTokens);

        uint etherRefundAmount = msg.value - etherAmount;

        ERC20 token = ERC20(tokenAddress);
        token.transfer(msg.sender, tokenAmount);

        if(etherRefundAmount > 0 )
            payable(msg.sender).transfer(msg.value - etherAmount);
    }   

    function tokenToEtherSwap(uint tokenAmount ) public  {
        // Approve() Tx가 진행된 상태 (지갑(?) -> tokenContract)
        ERC20 tokenContract = ERC20(tokenAddress);
        tokenContract.transferFrom(msg.sender, address(this), tokenAmount);
        uint etherAmount = tokenAmount;
        payable(msg.sender).transfer(etherAmount);
    }


    function addLiquidity (uint tokenAmount) public payable {
        uint etherAmount = msg.value;

        ERC20 tokenContract = ERC20(tokenAddress);
        tokenContract.transferFrom(msg.sender, address(this), tokenAmount);
        _mint(msg.sender, etherAmount);
    }


    function removeLiquidity (uint lpTokenAmount) public {
         ERC20 tokenContract = ERC20(tokenAddress);
        tokenContract.transfer(msg.sender, tokenContract.balanceOf(address(this))*lpTokenAmount / balanceOf(address(this)));
        payable(msg.sender).transfer(address(this).balance * lpTokenAmount / balanceOf(address(this)));
        _burn(msg.sender, lpTokenAmount);

    }

}