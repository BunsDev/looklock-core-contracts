//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/uitls/SafeERC20.sol";

contract Vault {
    public mapping(uint -> uint) public boost;  //days
    public mapping(uint -> uint) public canclePercent; 

    
    IERC20 public dropToken;
    IERC20 [] public lockTokens;
    // drop 예정인 총 토큰 양
    uint256 public totalSupply; 
    uint256 public remainingSupply; 
    uint public lockDuration;
    uint public start;

    uint[] public boostOption;
    uint[] public cancleOption;

    // cliff no need
    // uint constant THREE_MONTHS = 91;
    // uint constant SIX_MONTHS = 182;
    // uint constant NINE_MONTHS = 273;
    // uint constant TWELVE_MONTHS = 365;
    

    address public admin;
    address constant LOLO = "";
    bool public isActive;

    struct UserLockInfo {
        uint id;
        uint lockStart;
        uint lockEnd;
        address lockedToken;
        uint256 amount;
    }

    UserLockInfo[] public userLockInfos;

    public mapping(address -> userLockInfos) LockInfo;
    address[] public beneficiaries; 


    /**
    @dev Admin 권한, Beneficiary 권한 설정. 
     */
    modifier onlyAdmin {
        require(msg.sender == admin);
    }

     modifier onlyBeneficiary {
        require(isExistingBeneficiary(msg.sender));
    }
    /**
    @param _lockToken 락 할 토큰의 주소. 없으면 0 
    @param _totalSupply drop 할 토큰의 총 수량. 
    @param _lockDuration lock 진행할 기간
    @param _boostDays boost할 기준 시간들 (일 기준)
    @param _boostNums boost percent
    @param _cancleDays cancle 기준 시간들 (일 기준)
    @param _canclePercent cancle percent
    */
    constructor (
        address _lockToken, 
        uint256 _totalSupply, 
        uint _lockDuration,

        uint [] _boostDays,
        uint [] _boostNums,
        uint [] _cancleDays,
        uint [] _canclePercent
        
        )
    {
        /// LOLO 토큰은 기본적을 lock 토큰에 포함
        lockTokens.push(IERC20(LOLO));

        setLockAsset(_lockToken);
        totalSupply = _totalSupply;

        // 
        remainingSupply = totalSupply;
        lockDuration = _lockDuration;

        admin = msg.sender;
        isActive = false;

        boostOption = _boostDays;
        cancleOption = _cancleDays;

        for (uint i=0; i<boostOption.length; i++) {
        boost[_boostDays[i]] = _boostNums[i];
        }

        for (uint i=0; i<cancleOption.length; i++) {
        canclePercent[_cancleDays[i]] = _canclePercent[i];
        }
        
    }

    function setAdmin(address addr) external onlyAdmin {
        admin = addr;
    }

    function setLockAsset(address _lockToken) external onlyAdmin {
        require(!isExistingLockToken(IERC20(lockedToken)), "Already exsits as LockAsset");
        lockToken = IERC20(_lockToken);
        lockTokens.push(lockToken);
    }

    function setDropAsset(address _dropToken) external onlyAdmin {
        dropToken = IERC20(_dropToken);
    }

    /// initiagte 하기 전에 프로젝트 오너가 vault 에 totalSupply 만큼의 토큰을 transfer 해야 함. (scritpt 단에서 처리)
    function initiateLock(address _dropToken, uint256 total) isAdmin external onlyAdmin{
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

    function isExistingLockToken(IERC20 token) returns(bool) {
        for (uint i; i < lockedTokens.length; i++) {
            if (lockedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    function isExistingBeneficiary(address addr) internal returns(bool) {
        for (uint i; i<beneficiaries.length, i++ ) {
            if (beneficiaries[i] == addr) {
                return true;
            }
        }
        return false;
    }
    
    /// need to approve first (프론트에서 처리)
    function deposit(uint256 amount, uint lockDurationInDays, address lockedToken, uint256 amount ){
        IERC20 token = IERC20(lockedToken);
        require(msg.sender != admin, "Admin cannot deposit for lockdrop");
        require(isExistingLockToken(token), "Wrong type of Token to lock");
        /// remaining supply 보다 적거나 같은 양이어야 함.
        require(amount <= remainingSupply, "Exceeds remaining supply");
        require(block.timestamp + lockDurationInDays days < start + lockDuration, "exceeds lock duration");
        
        // require(amount < totalSupply - token.balanceOf(address(this)))
        safeTransferFrom(lockToken, msg.sender, address(this), amount);
        uint length = LockInfo[msg.sender].length;
        LockInfo[msg.sender].push(UserLockInfo(
            length-1, 
            block.timestamp, 
            block.timestamp + lockDurationInDays days,
            lockedToken,
            amount
            ))

        remainingSupply -= amount;
        if(!isExistingBeneficiary(msg.sender)) {
            beneficiaries.push(msg.sender);
        }
    }

    /// withdraw only locked token
    function withdraw(address lockedToken, uint id) onlyBeneficiery{
        
        IERC20 token = IERC20(lockedToken);
        require(isExistingLockToken(token), "Wrong type of Token to withdraw");
        require(LockInfo[msg.sender].length > id, "Id out of index");
        require(LockInfo[msg.sender][id].amount > 0 , "Nothing to withdraw");

        require(block.timestamp - lockStart < cancleOption[cancleOption.length -1] days, "Available cancle date has passed");
        uint lockStart = LockInfo[msg.sender][id].lockStart;
        uint256 amount = 0

        for (uint i; i<cancleOption.length ; i++) {
            if(block.timestamp - lockStart < cancleOption[i]){
                amount = LockInfo[msg.sender][id].amount * (canclePercent[cancleOption[i]]/100);
            }
        }
        token.transfer(msg.sender, amount);
        /// set lock info amoutn to 0
        LockInfo[msg.sender][id].amount = 0;
    }

    /// claim for lockdrop
    function claim() onlyBeneficiery{
        uint256 claimableAmount = 0 
        for (uint i=0; i < lockedTokens.length; i++){
            IEC20 token = lockedTokens[i];
            uint256 withdrawAmount = 0; 
            for ( uint j; j< LockInfo[msg.sender].length; j++ ) {
                if (block.timestamp < LockInfo[msg.sender][j].endLock){
                    continue;
                }
                if (LockInfo[msg.sender][j].token == token) {
                    withdrawAmount += LockInfo[msg.sender][j].amount;
                }
                claimableAmount += getEffectiveValue(
                    LockInfo[msg.sender][j].amount,
                    LockInfo[msg.sender][j].startLock,
                    LockInfo[msg.sender][j].endLock );
            }

            if(withdrawAmount >0 ) {
                token.transfer(msg.sender, withdrawAmount);
            }
        }
        
        dropToken.transfer(msg.sender, claimableAmount)

    }
    
    function getEffectiveValue(uint256 amount, uint start, uint end) {
        uint term = end - start; 
        uint256 bonus= 100; 
        for(uint i=0; i<boostOption.length ; i++) {
            if (term < boosOtption[i] days) {
                return amount * boost[boostOption[i]]/100;
            }
        return amount * boost[boostOption[boosOption.length-1]];
        }

    }

    function closeLock() onlyAdmin {
        require(isActive = true, "Already closed");
        isActive=false;
        dropToken.transfer(msg.sender, dropToken.balanceOf(address(this)));
    }

    /**
    @TODO 최대 1대1 교환. boost 가 아니라 portion 이어야 할 듯?  +  cliff no need?
     */ 
    
}