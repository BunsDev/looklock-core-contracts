//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault {
    using SafeERC20 for IERC20;

    mapping(uint8 => uint8) public durationBoost; 
    mapping(uint8 => uint8) public canclePercent;  

    
    IERC20 public dropToken;
    IERC20 [] public lockTokens;
    // drop 예정인 총 토큰 양
    uint256 public totalSupply; 
    uint256 public remainingSupply; 
    uint256 public lockPeriod;
    uint256 public start;

    uint8[] public cancleOption;  ///days

    address public admin;
    bool public isActive;


    struct AllocationPerDuration {
        // Duration duration;
        bool active;
        uint8 boost;
        uint256 allocation;
        uint256 remain;
    }

    struct UserLockInfo {
        uint8 id;
        uint8 duration;
        uint256 lockStart;
        uint256 lockEnd;
        uint256 amount;
        address lockedToken;
    }

    address[] public beneficiaries;

    uint8[] public durations;
    mapping(uint8 => AllocationPerDuration)public Allocation; 

    UserLockInfo[] public userLockInfos;
    mapping(address => UserLockInfo[]) public LockInfo;


    /**
    @dev Admin 권한, Beneficiary 권한 설정. 
     */
    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

     modifier onlyBeneficiery {
        require(isExistingBeneficiary(msg.sender));
        _;
    }

    /**
    @param _lockPeriod lock 진행할 기간
    @param LOLO lolo contract address
    @param _durationOption duration 기간들 (day)
    @param _boostOption duration 기간 별 boost 수치
    @param _cancleOption cancle 기준 시간들 (일 기준)
    @param _percent cancle percents
    @param _allocation token allocations per duration
    */
    constructor ( 
        uint _lockPeriod,
        address LOLO,

        uint8 [] memory _durationOption,
        uint8 [] memory _boostOption,
        uint8 [] memory _cancleOption,
        uint8 [] memory _percent,

        uint256[] memory _allocation
        
        )
    {
        //compute total supply
        totalSupply = 0;
        for(uint i=0; i < _durationOption.length; i++) {
            uint8 duration = _durationOption[i];
            uint8 boost = _boostOption[i];
            uint256 allocation = _allocation[i];

            durations.push(duration);

            Allocation[duration] = AllocationPerDuration(
                true, boost, allocation, allocation
            );


            durationBoost[duration] = boost;
            totalSupply += boost * allocation;
        }

        cancleOption = _cancleOption;
        for (uint i=0; i<cancleOption.length; i++) {
            canclePercent[cancleOption[i]] = _percent[i];
        }
   
        /// LOLO 토큰은 기본적을 lock 토큰에 포함
        lockTokens.push(IERC20(LOLO));

        remainingSupply = totalSupply;
        lockPeriod = _lockPeriod;

        admin = msg.sender;
        isActive = false;
        
    }

    function setAdmin(address addr) external onlyAdmin {
        admin = addr;
    }

    function setLockAsset(address _lockToken) external onlyAdmin {
        require(!isExistingLockToken(IERC20(_lockToken)), "Already exsits as LockAsset");
        lockTokens.push(IERC20(_lockToken));
    }

    function setDropAsset(address _dropToken) external onlyAdmin {
        dropToken = IERC20(_dropToken);
    }

    /// initiagte 하기 전에 프로젝트 오너가 vault 에 totalSupply 만큼의 토큰을 transfer 해야 함. (scritpt 단에서 처리)
    function initiateLock() external onlyAdmin{
        require(dropToken.balanceOf(address(this)) == totalSupply, 
                "Not enough dropToken in vault. Need to transfer drop first.");

        if (!isActive) {
            isActive = true;
            start = block.timestamp;
        }
        else {
            revert("Project is already started");
        }
    }

    function isExistingLockToken(IERC20 token) internal view returns(bool) {
        for (uint i=0; i < lockTokens.length; i++) {
            if (lockTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function isExistingBeneficiary(address addr) internal view returns(bool) {
        for (uint i=0; i<beneficiaries.length; i++ ) {
            if (beneficiaries[i] == addr) {
                return true;
            }
        }
        return false;
    }
    
    /// need to approve first (프론트에서 처리)
    function deposit(uint256 amount, uint8 _duration, address lockedToken ) public {
        IERC20 token = IERC20(lockedToken);
        require(msg.sender != admin, "Admin cannot deposit for lockdrop");
        require(isExistingLockToken(token), "Wrong type of Token to lock");

        uint8 duration = _duration;
        /// 해당 duration 이 active 해야함
        require(Allocation[duration].active, "The Allocation of Duration is full");
        /// remaining supply 보다 적거나 같은 양이어야 함.
        require(Allocation[duration].remain >= amount, "Exceeds remaining supply");
        /// lock할 기간이 전체 프로젝트 기간 이내여야 함. 
        require(block.timestamp + _duration * 1 days < start + lockPeriod, "exceeds lock duration");
        
        
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint length = LockInfo[msg.sender].length;
        LockInfo[msg.sender].push(UserLockInfo(
            uint8(length-1), 
            duration,
            block.timestamp, 
            block.timestamp + _duration * 1 days,
            amount,
            lockedToken
            ));

        Allocation[duration].remain -= amount;
        if(!isExistingBeneficiary(msg.sender)) {
            beneficiaries.push(msg.sender);
        }
    }

    /// withdraw only locked token
    function withdraw(address lockedToken, uint id) public onlyBeneficiery{
        
        IERC20 token = IERC20(lockedToken);
        require(isExistingLockToken(token), "Wrong type of Token to withdraw");
        require(LockInfo[msg.sender].length > id, "Id out of index");
        require(LockInfo[msg.sender][id].amount > 0 , "Nothing to withdraw");
        
        uint startTime = LockInfo[msg.sender][id].lockStart;
        require(block.timestamp - startTime < cancleOption[cancleOption.length -1] * 1 days, "Available cancle date has passed");
        
        uint256 amount = 0;

        for (uint i=0; i<cancleOption.length ; i++) {
            if(block.timestamp - startTime < cancleOption[i]){
                amount = LockInfo[msg.sender][id].amount * (canclePercent[cancleOption[i]]/100);
                break;
            }
        }
        token.transfer(msg.sender, amount);
        /// set lock info amoutn to 0
        LockInfo[msg.sender][id].amount = 0;
    }

    /// claim for lockdrop and unlock the asset. unlock 가능한 asset만 redeem, 나머지는 계속 Lock상태.
    function claim() public onlyBeneficiery{
        uint256 claimableAmount = 0;
        for (uint i=0; i < lockTokens.length; i++){
            IERC20 token = lockTokens[i];
            uint256 unlockAmount = 0; 
            for ( uint j; j< LockInfo[msg.sender].length; j++ ) {
                /// lock이 끝나지 않은 토큰은 제외
                if (block.timestamp < LockInfo[msg.sender][j].lockEnd){
                    continue;
                }
                // unlock the token
                uint256 amount = LockInfo[msg.sender][j].amount;
                if (IERC20(LockInfo[msg.sender][j].lockedToken) == token) {
                    unlockAmount += amount;
                    LockInfo[msg.sender][j].amount = 0;
                }
                // unlock 된 asset 기반으로 claim할 amount 계산
                claimableAmount += getEffectiveValue(
                    amount,
                    LockInfo[msg.sender][j].duration
                    );
            }

            if(unlockAmount >0 ) {
                token.transfer(msg.sender, unlockAmount);
            }
        }
        if (claimableAmount > 0 ) {
            dropToken.transfer(msg.sender, claimableAmount);
        }

    }
    
    function getEffectiveValue(uint256 amount, uint8 duration) internal view returns(uint256) {

        return Allocation[duration].boost * amount;
    }

    function closeLock() public onlyAdmin {
        require(isActive = true, "Already closed");
        isActive=false;
        dropToken.transfer(msg.sender, dropToken.balanceOf(address(this)));
    }

    /**
    @TODO 최대 1대1 교환. boost 가 아니라 portion 이어야 할 듯?  +  cliff no need?
     */ 
    
}