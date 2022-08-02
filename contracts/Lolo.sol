//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./ILolo.sol";

contract Lolo is ERC20, Ownable, ILolo {
    
    /**
    @dev
    - 거버넌스 토큰에 대한 기획이 일단 없어서 아주 기본 기능만 넣었습니다.
    - lolo 토큰을 사용을 테스트 하고 싶을 땐 일단 owner 계정에서 테스트 원하는 계정으로 minting 해서 사용해주세요.
    */

    constructor(uint256 _initialSupply) ERC20("LookLock", "LOLO") {
        
        _mint(msg.sender, _initialSupply);
    }

    function swap(address asset, uint amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    function changeOwner(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

}