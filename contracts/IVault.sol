//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault{
    function setAdmin(address addr) external;

    function setLockAsset(address _lockToken) external;

    function startProject() external ;

    function deposit(uint256 amount, uint8 _period, IERC20 lockedToken ) external ;

    function withdraw(uint8 period, uint id) external;

    function claim(uint8 period, uint id) external;

    function closeLock() external ;


}