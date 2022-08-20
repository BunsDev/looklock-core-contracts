//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Lolo.sol";
import "./IVault.sol";

contract VaultFactory{
    Vault[] public VaultArray;

    function CreateNewVault(
        address LOLO,

        uint8 _phase1Period,
        address _rewardToken,
        uint8 [] memory _phase2Periods,
        uint8 [] memory _withdrawablePercents,
        
        uint8 [] memory _lockPeriods,
        uint8 [] memory _multipliers,
        uint256[] memory _allocations
        ) public {
        
        Vault vault = new Vault( 
            LOLO, 
            _phase1Period, 
            _rewardToken, 
            _phase2Periods, 
            _withdrawablePercents, 
            _lockPeriods, 
            _multipliers, 
            _allocations, 
            msg.sender);
        VaultArray.push(vault);
    }

    function getVaults() external view returns (Vault[] memory) {
        return VaultArray;
    }


}

contract Vault is IVault{
    using SafeERC20 for IERC20;

    /**
    * Data need to be set when project starts
    */
    uint256 public startDate;
    uint256 public phase1Due;
    // percent in phase2 period - duedate
    mapping(uint8 => uint256) public withdrawablePercentPerDue;
    uint256 public lockStartDate;
    uint256 public lockDueDate;
    bool public isActive = false;

    /**
    * Data need to be set in constructor
    */
    // phase1
    uint8 public phase1Period;
    //phase2, withdrawpercent
    uint8[] public phase2Periods;
    uint256 public lockPeriod =0;
    uint8[] public withdrawablePercents;
    //lockPeriod-boosts
    mapping(uint8 => uint8) public lockPeriodMultipliers;

    struct Allocation {
        // Duration duration;
        bool active;
        uint8 boost;
        uint256 allocation;
        uint256 remain;
    }
    //lockPeriond-Allocation
    mapping(uint8 => Allocation) private _allocationPerPeriod;
    uint256 public totalAllocation = 0;

    // reward token Info
    IERC20 public rewardToken;
    address public admin;

    /**
    * Data need to be set in other function;
    */
    IERC20 [] public lockTokens;
    


    struct UserLockInfo {
        uint256 id;
        uint256 amount;
        uint256 unlockAt;
        bool isWithdrawed;
        bool isClaimed;
        IERC20 lockedToken;
    }

    address[] public beneficiaries;
    // address - (lock period - amount)
    mapping(address => mapping ( uint8 =>  UserLockInfo[])) public LockInfo;


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

    
    constructor ( 
        address LOLO,

        uint8 _phase1Period,
        address _rewardToken,
        uint8 [] memory _phase2Periods,
        uint8 [] memory _withdrawablePercents,
        
        uint8 [] memory _lockPeriods,
        uint8 [] memory _multipliers,
        uint256[] memory _allocations,

        address _admin
        )
    {
        phase1Period = _phase1Period;
        phase2Periods = _phase2Periods;
        withdrawablePercents = _withdrawablePercents;
        
        for (uint i=0; i< _lockPeriods.length; i++) {
            Allocation memory allocation = Allocation(
                true,
                _multipliers[i],
                _allocations[i],
                _allocations[i]
                );

            _allocationPerPeriod[_lockPeriods[i]] = allocation;
            totalAllocation +=  _allocations[i];
            lockPeriod += _lockPeriods[i];
        }

        rewardToken = IERC20(_rewardToken);
        admin = _admin;
        /// LOLO 토큰은 기본적을 lock 토큰에 포함
        lockTokens.push(IERC20(LOLO));
    }

    function setAdmin(address addr) external onlyAdmin {
        admin = addr;
    }

    function setLockAsset(address _lockToken) external onlyAdmin {
        require(!isExistingLockToken(IERC20(_lockToken)), "Already exsits as LockAsset");
        lockTokens.push(IERC20(_lockToken));
    }

    /// initiagte 하기 전에 프로젝트 오너가 vault 에 totalSupply 만큼의 토큰을 transfer 해야 함
    function startProject() external onlyAdmin {
        require(rewardToken.balanceOf((address(this))) == totalAllocation,
         "Not enough dropToken in vault. Need to transfer drop first.");
        
        if (isActive) {
            revert("Already started project");
        }
        startDate = block.timestamp;
        phase1Due = block.timestamp + phase1Period * 1 days;
        uint256 applyPeriod = phase1Period;
        for (uint i =0; i< phase2Periods.length; i++) {
            uint256 due = phase2Periods[i] * 1 days + block.timestamp;
            withdrawablePercentPerDue[withdrawablePercents[i]] = due;
            applyPeriod += phase2Periods[i];
        }
        lockStartDate = applyPeriod * 1 days + block.timestamp;
        lockDueDate = lockStartDate + lockPeriod * 1 days;
        isActive = true;

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

    event UserDeposit(address user, uint lockInfoId);
    
    /// need to approve first (프론트에서 처리)
    function deposit(uint256 amount, uint8 _period, IERC20 lockedToken ) external {
        IERC20 token = IERC20(lockedToken);
        require(msg.sender != admin, "Admin cannot deposit for lockdrop");
        require(isExistingLockToken(token), "Wrong type of Token to lock");
        require(block.timestamp < phase1Due, "depositalbe period has passed");

        uint8 period = _period;
        /// 해당 duration 이 active 해야함
        require(_allocationPerPeriod[period].active, "The Allocation of Duration is full");
        /// remaining supply 보다 적거나 같은 양이어야 함.
        require(_allocationPerPeriod[period].remain >= amount, "Exceeds remaining supply");
        
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 id = LockInfo[msg.sender][period].length -1;

        LockInfo[msg.sender][period].push(UserLockInfo(
            id, 
            amount,
            lockStartDate + (period+1)* 1 days,
            false,
            false,
            lockedToken
            ));
        
        _allocationPerPeriod[period].remain -= amount;
        if(!isExistingBeneficiary(msg.sender)) {
            beneficiaries.push(msg.sender);
        }
        emit UserDeposit(msg.sender, id);

    }

    /// withdraw only locked token
    function withdraw(uint8 period, uint id) external onlyBeneficiery{
        
        require(LockInfo[msg.sender][period].length > id, "Id out of index");
        require(! LockInfo[msg.sender][period][id].isWithdrawed , "Already withdrawed");
        require(block.timestamp < lockStartDate, "Lock has started. Cannot withdraw");
        UserLockInfo storage lock = LockInfo[msg.sender][period][id];
        uint256 percent = 100;

        for (uint i=0; i<withdrawablePercents.length ; i++) {
            if(block.timestamp <= phase1Due) break;
            if(block.timestamp <= withdrawablePercentPerDue[withdrawablePercents[i]]){
                percent = withdrawablePercents[i];
                break;
            }
        }
        uint256 amount = lock.amount * (percent/100);
        lock.lockedToken.transfer(msg.sender, amount);
        /// set lock info withdrawed true
        lock.isWithdrawed = true;
        
    }

    function claim(uint8 period, uint id) external onlyBeneficiery{
        require( block.timestamp > LockInfo[msg.sender][period][id].unlockAt, "Cannot claim yet");
        require(LockInfo[msg.sender][period][id].isWithdrawed == false, "Already withdrawed");
        require(LockInfo[msg.sender][period][id].isClaimed == false, "Already claimed");
        UserLockInfo storage lock = LockInfo[msg.sender][period][id];
        uint256 amount = getEffectiveValue(lock.amount, period);
        lock.lockedToken.transfer(msg.sender, amount);
        lock.isClaimed = true;
    }
    
    function getEffectiveValue(uint256 _amount, uint8 _period) internal view returns(uint256) {

        return _allocationPerPeriod[_period].boost * _amount;
    }

    function closeLock() external onlyAdmin {
        require(isActive = true, "Already closed");
        isActive=false;
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }
    
}