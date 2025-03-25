// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Pool.sol";
import "./interfaces/IFactory.sol";
import "./lib/utils.sol";

contract Factory is IFactory{
    
    event NewPool(
        address indexed token0,
        address indexed token1,
        address indexed Pair
    );

    address public owner;
    mapping(address=>mapping(address=>address)) public tokensToPool;

    constructor(){
        owner = msg.sender;
    }

    /** 
    * @notice Factory로부터 새로운 Pair를 생성하는 함수
    * @param tokenA ETH/Token 풀의 TokenA의 주소
    * @param tokenB ETH/Token 풀의 TokenB의 주소
    * @return 만들어진 ETH/Token Pair의 주소를 반환
    */
    function createPool(address tokenA, address tokenB) public returns (address){

        (address token0, address token1) = Library.sortTokens(tokenA, tokenB);

        require(tokensToPool[token0][token1] == address(0));

        Pool p = new Pool(token0, token1);
        address _pool = address(p);
        tokensToPool[token0][token1] = _pool;
        tokensToPool[token1][token0] = _pool;
        emit NewPool(token0, token1, _pool);
        return _pool;
    }

    function getTokensToPool(address token0, address token1) external view returns(address pair){
        return tokensToPool[token0][token1];
    }

}