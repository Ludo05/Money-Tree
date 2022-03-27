// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import './T.sol';
/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract Factory {

    MoneyController private moneyController;
    address payable contractToSend;

    constructor(address moneyControllerAddress) {
        moneyController = MoneyController(payable(moneyControllerAddress));
        contractToSend = payable(moneyControllerAddress);
    }

    function sendEther() external payable {
        (bool sent, ) = contractToSend.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }

    function getBalance() external view returns (uint) {
        return moneyController.balance();
    }


}
