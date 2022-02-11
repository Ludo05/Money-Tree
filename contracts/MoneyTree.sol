// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
/**
 * @title MoneyTree token contract.
  * @dev ERC20 token contract.
 */

contract MoneyTree is ERC20, Ownable, ERC20Burnable {
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 initialSupply
    ) payable ERC20(_tokenName, _tokenSymbol) {

        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);

    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);

    }

    function increaseAllowanceToSpender(address spender, uint256 amount) public {
        increaseAllowance(spender,amount);
    }

}
