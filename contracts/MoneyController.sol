// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9 ;

contract MoneyController {

    address public owner;
    uint private fees;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        fees += msg.value;
    }

    receive() external payable {
        fees += msg.value;
    }



    function _transfer(uint amount) external payable {
        require(msg.sender == owner, "OnlyOwner");
        payable(address(this)).transfer(amount);
    }


    function withdraw() external {
        require(msg.sender == owner, "OnlyOwner");
        payable(msg.sender).transfer(address(this).balance);
    }

    function balance () external view returns (uint Balance) {
        Balance = address(this).balance;

    }
}
