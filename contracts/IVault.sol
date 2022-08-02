//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault{
    function setAdmin(address addr) external;

    function setLockAsset(address _lockToken) external;

    function setDropAsset(address _dropToken) external;

    function initiateLock() external ;

    function deposit(uint256 amount, uint8 _duration, address lockedToken ) external ;

    function withdraw(address lockedToken, uint id) external;

    function claim() external;

    function closeLock() external ;


}