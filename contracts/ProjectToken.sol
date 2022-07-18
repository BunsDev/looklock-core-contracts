//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ProjectToken is ERC20, Ownable {
    
    address vault;

    constructor(string memory name, string memory symbol, uint256 _initialSupply, address _vault) ERC20(name, symbol) {
        vault = _vault;
        _mint(vault, _initialSupply);
    }

    function changeOwner(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

}