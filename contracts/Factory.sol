// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Exchange.sol";

contract Factory {
    
    event NewExchange(
        address indexed token,
        address indexedexchange
    );

    address public owner;
    mapping(address=>address) public addrToExchange;
    mapping(address=>address) public exchangeToAddr;

    constructor(){
        owner = msg.sender;
    }

    /** 
    * @notice Factory로부터 새로운 Exchange를 생성하는 함수
    * @param _address ETH/Token 풀의 Token Contract의 Address
    * @return 만들어진 ETH/Token Exchange의 주소를 반환
    */
    function createExchange(address _address) public returns (address){

        require(_address != address(0));
        require(addrToExchange[_address] == address(0));

        Exchange ex = new Exchange(_address);
        address exAddr = address(ex);
        addrToExchange[_address] = exAddr;
        exchangeToAddr[exAddr] = _address;
        emit NewExchange(_address, exAddr);
        return exAddr;
    }

    /**
     * @notice Token Address-> Exchange Address mapping 결과를 반환하는 함수
     * @param _address Token Address
     * @return Token Address와 mapping된 Exchange Address 반환
     */
    function getAddrToExchange(address _address) view public returns (address){
        return addrToExchange[_address];
    }


    /**
     * @notice Exchange Address-> Token Address mapping 결과를 반환하는 함수
     * @param _address Exchange Address
     * @return Exchange Address와 mapping된 Token Address 반환
     */
    function getExchangeToAddr(address _address) view public returns (address){
        return exchangeToAddr[_address];
    }
}