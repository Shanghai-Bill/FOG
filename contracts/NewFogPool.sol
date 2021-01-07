pragma solidity ^0.5.17;

// Adapted from SushiSwap's MasterChef contract
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./FOG.sol";

contract FoggyBogTwo is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        //
        //   pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakableToken; // Address of staking token contract.
        uint256 allocPoint; // How many FOG to distribute per block.
        uint256 lastRewardBlock;
        uint256 accFogPerShare; // Accumulated FOG per share, times 100. See below.
    }

    // FOG Address
    FOG public fog;

    // Amount of FOG allocated to pool per block
    uint256 fogPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocatuion  points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // start block
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        FOG _fog,
        uint256 _fogPerBlock,
        uint256 _startBlock
    ) public {
        fog = _fog;
        fogPerBlock = _fogPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new token or LP to the pool. Can only be called by the owner.
    // DO NOT add the same LP or token more than once. Rewards will be messed up if you do.

    function add(
        uint256 _allocPoint,
        IERC20 _stakableToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                stakableToken: _stakableToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accFogPerShare: 0
            })
        );
    }

    // Update the given pool's FOG allocation pointpercentage. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from);
    }

    // View function to see pending FOG on frontend.
    function pendingFOG(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFogPerShare = pool.accFogPerShare;
        uint256 stakedSupply = pool.stakableToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && stakedSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 fogReward =
                multiplier.mul(fogPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );

            accFogPerShare = accFogPerShare.add(
                fogReward.mul(1e12).div(stakedSupply)
            );
        }
        return user.amount.mul(accFogPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 stakedSupply = pool.stakableToken.balanceOf(address(this));
        if (stakedSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);

        uint256 fogReward =
            multiplier.mul(fogPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        pool.accFogPerShare = pool.accFogPerShare.add(
            fogReward.mul(1e12).div(stakedSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Claim all if no amount specified, or Deposit new LP/SAS.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        // this is claim
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accFogPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeFOGtransfer(msg.sender, pending);
            }
        } /// Deposit
        if (_amount > 0) {
            uint256 beforeAmount = pool.stakableToken.balanceOf(address(this));
            pool.stakableToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );

            uint256 _addAmt =
                pool.stakableToken.balanceOf(address(this)).sub(beforeAmount);

            user.amount = user.amount.add(_addAmt);
        }
        user.rewardDebt = user.amount.mul(pool.accFogPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw or Claim FOG/LP/SaS tokens from FoggyBogTwo.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accFogPerShare).div(1e12).sub(user.rewardDebt); // Claim first all that is pending
        if (pending > 0) {
            safeFOGtransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            // Remove stake
            user.amount = user.amount.sub(_amount);
            pool.stakableToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accFogPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakableToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe FOG transfer function, just in case if rounding error causes pool to not have enough FOG.
    function safeFOGtransfer(address _to, uint256 _amount) internal {
        uint256 fogBal = fog.balanceOf(address(this));
        if (_amount > fogBal) {
            fog.transfer(_to, fogBal);
        } else {
            fog.transfer(_to, _amount);
        }
    }

    function updatefogPerBlock(uint256 _fogPerBlock)
        external
        onlyOwner
        returns (bool)
    {
        fogPerBlock = _fogPerBlock;
        return true;
    }

    function getFogBalance() external view returns (uint256) {
        uint256 FogBalance = fog.balanceOf(address(this));
        return FogBalance;
    }

    function getFogPerBlock() external view returns (uint256) {
        return fogPerBlock;
    }
}
