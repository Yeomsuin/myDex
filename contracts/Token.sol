// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20{
    address public owner;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        owner = msg.sender;
    }

    /**
     * @notice 토큰의 양은 1e18을 곱한 스케일로 적용된다.
     * @param to  해당 주소를 가진 유저에게 amount만큼의 토큰을 발행한다.
     * @param amount 토큰 발행량
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
