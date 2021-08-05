// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IRandomNumberConsumer.sol";

/**
 * @title UnifiedLiquidityPool Contract
 */

contract UnifiedLiquidityPool is ERC20, Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @notice Event emitted only on construction.
    event UnifiedLiquidityPoolDeployed();

    /// @notice Event emitted when owner initialize staking.
    event stakingStarted(uint256 GBTSAmount);

    /// @notice Event emitted when user stake GBTS token
    event staked(address staker, uint256 GBTSAmount, uint256 sGBTSAmount);

    /// @notice Event emitted when user exit staking
    event stakeExit(address staker, uint256 GBTSAmount, uint256 sGBTSAmount);

    /// @notice Event emitted when sGBTS put into the dividend pool
    event sharesAdded(address provider, uint256 shares);

    /// @notice Event emitted when sGBTS is removed from dividend pool
    event sharesRemoved(address provider, uint256 shares);

    /// @notice Event emitted when distributed
    event distributed(uint256 distributionAmount, address receiver);

    /// @notice Event emitted when dividend pool is changed
    event dividendPoolAddressChanged(address ulpDivAddr, uint256 burnAmount);

    /// @notice Event emitted when game unlock is initiated
    event gameApprovalUnlockInitiated(address gameAddr);

    /// @notice Event emitted when game is approved
    event gameApproved(address gameAddr, bool approved);

    /// @notice Event emitted when prize is sent to the winner
    event prizeSent(address gameAddr, address winner, uint256 GBTSAmount);

    /// @notice Event emitted when only burn sGBTS token
    event sGBTSburnt(uint256 sGBTSAmount);
    
    /// @notice Event emitted only when batch block changes
    event batchGroupingChanged(uint256 nextCall);

    struct dividendPool {
        address provider;
        uint256 shares;
        uint256 profits;
    }

    /// @notice Approved Game List
    address[] public approvedGamesList;

    /// @notice Current game is approved
    mapping(address => bool) public isApprovedGame;

    /// @notice GBTS token instance
    IERC20 public GBTS;

    /// @notice Random Number Consumer instance
    IRandomNumberConsumer public RNG;

    /// @notice Boolean variable for checking whether staking is started or not
    bool public isStakingStarted;

    /// @notice Weight of current distribution amount
    uint256 public currentWeight;

    /// @notice Stakers array in dividend pool
    dividendPool[] public stakers;

    /// @notice Track the provider index in dividend pool
    mapping(address => uint256) public providerIndex;

    /// @notice Point the next receipent in dividend pool
    uint256 public indexProvider;

    /// @notice Amount of limit can be distributed
    uint256 constant balanceControlULP = 45000000 * 10**18;

    /// @notice Distribution weight
    uint256 public distribution;

    bytes32 private currentRequestId;

    uint256 private constant APPROVAL_TIMELOCK = 1 days;

    mapping(address => uint256) public gameApprovalLockTimestamp;

    mapping(bytes32 => uint256) randomMatch;

    mapping(bytes32 => bool) hasReturned;

    uint256 lastBlockNumber;

    uint256 nextCall;

    mapping(address => uint256) gameIndex;

    uint256 public dividendTotal;

    modifier canStake() {
        require(isStakingStarted, "ULP: Owner must initialize staking");
        _;
    }

    modifier onlyApprovedGame() {
        require(isApprovedGame[msg.sender], "ULP: Game is not approved");
        _;
    }

    modifier gameApprovalNotLocked(address _gameAddr) {
        require(
            gameApprovalLockTimestamp[_gameAddr] != 0,
            "ULP: Game approval unlock not initiated"
        );
        require(
            block.timestamp >=
                gameApprovalLockTimestamp[_gameAddr] + APPROVAL_TIMELOCK,
            "ULP: Game approval under timelock"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of Random Number Generator
     */
    constructor(IERC20 _GBTS, IRandomNumberConsumer _RNG)
        ERC20("Stake GBTS", "sGBTS")
    {
        GBTS = _GBTS;
        RNG = _RNG;
        emit UnifiedLiquidityPoolDeployed();
        nextCall = 3;
    }

    /**
     * @dev External function to start staking. Only owner can call this function.
     * @param _initialStake Amount of GBTS token
     */
    function startStaking(uint256 _initialStake) external onlyOwner {
        require(!isStakingStarted, "ULP: FAIL");

        require(
            GBTS.balanceOf(msg.sender) >= _initialStake,
            "ULP: Caller has not enough balance"
        );

        GBTS.safeTransferFrom(msg.sender, address(this), _initialStake);

        _mint(address(this), _initialStake);

        isStakingStarted = true;
        stakers.push(dividendPool(address(this), _initialStake, 0));
        dividendTotal += _initialStake;
        emit stakingStarted(_initialStake);
    }

    /**
     * @dev External function for staking. This function can be called by any users.
     * @param _amount Amount of GBTS token
     */
    function stake(uint256 _amount) external canStake {
        require(
            GBTS.balanceOf(msg.sender) >= _amount,
            "ULP: Caller has not enough balance"
        );

        uint256 feeAmount = (_amount * 3) / 100;

        uint256 sGBTSAmount = ((_amount - feeAmount) * totalSupply()) /
            ((GBTS.balanceOf(address(this)) + currentWeight));

        GBTS.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, sGBTSAmount);

        emit staked(msg.sender, _amount, sGBTSAmount);
    }

    /**
     * @dev External function to exit staking. Users can withdraw their funds.
     * @param _amount Amount of sGBTS token
     */
    function exitStake(uint256 _amount) external canStake nonReentrant {
        require(
            balanceOf(msg.sender) >= _amount,
            "ULP: Caller has not enough balance"
        );

        uint256 stakeValue = (_amount * GBTS.balanceOf(address(this))) /
            totalSupply();

        uint256 toSend = (stakeValue * 97) / 100;

        if (distribution > 0) {
            uint256 removeDis = (currentWeight * _amount) / totalSupply();
            currentWeight = currentWeight - removeDis;
        }
        _burn(msg.sender, _amount);

        GBTS.safeTransfer(msg.sender, toSend);

        if (totalSupply() == 0) {
            isStakingStarted = false;
        }

        emit stakeExit(msg.sender, toSend, _amount);
    }

    /**
     * @dev External function to allow sGBTS holder to deposit their token to earn direct deposits of GBTS into their wallets
     * @param _amount Amount of sGBTS
     */
    function addToDividendPool(uint256 _amount) external {
        require(
            balanceOf(msg.sender) >= _amount,
            "ULP: Caller has not enough balance"
        );

        require(transfer(address(this), _amount), "ULP: Transfer failed");
        dividendTotal += _amount;
        uint256 index = providerIndex[msg.sender];

        if (stakers[index].provider == msg.sender && index != 0) {
            stakers[index].shares = stakers[index].shares + _amount;
        } else {
            providerIndex[msg.sender] = stakers.length;
            stakers.push(dividendPool(msg.sender, _amount, 0));
        }

        emit sharesAdded(msg.sender, _amount);
    }

    /**
     * @dev External function for getting amount of sGBTS which caller in DividedPool holds.
     */
    function getBalanceofUserHoldInDividendPool()
        external
        view
        returns (uint256)
    {
        uint256 index = providerIndex[msg.sender];
        require(
            stakers[index].provider == msg.sender,
            "ULP: Caller is not in dividend pool."
        );

        return stakers[index].shares;
    }

    /**
     * @dev External function to withdraw from the dividendPool.
     * @param _amount Amount of sGBTS
     */
    function removeFromDividendPool(uint256 _amount) external nonReentrant {
        uint256 index = providerIndex[msg.sender];

        require(index != 0, "ULP: Index out of bounds");
        require(stakers[index].shares >= _amount, "ULP: Not enough shares");

        uint256 feeAmount = _amount / 25; //4% fee
        stakers[index].shares = stakers[index].shares - _amount;
        dividendTotal = dividendTotal - _amount;
        _burn(address(this), feeAmount);

        uint256 amountToSend = _amount - feeAmount;

        _transfer(address(this), msg.sender, amountToSend);

        emit sharesRemoved(msg.sender, _amount);
    }

    /**
     * @dev Public function to check to see if the distributor has any sGBTS then distribute. Only distributes to one provider at a time.
     *      Only if the ULP has more then 45 million GBTS.
     */
    function distribute() public nonReentrant {
        if (GBTS.balanceOf(address(this)) >= balanceControlULP) {
            dividendPool storage user = stakers[indexProvider];
            if (user.provider != address(this)) {
                if (stakers[indexProvider].shares == 0) {
                    // Current Staker hasn't got any sGBTS. That means that user isn't staker anymore. So remove that user in Stakers pool.
                    // And replace last staker to that user who hasn't got any sGBTS.

                    stakers[indexProvider] = stakers[stakers.length - 1];
                    providerIndex[
                        stakers[stakers.length - 1].provider
                    ] = indexProvider;
                    providerIndex[user.provider] = 0;
                    stakers.pop();

                    emit distributed(0, user.provider);
                } else {
                    //Set to sGBTS % to 2millGBTS
                    uint256 sendAmount = (user.shares * 2000000 * 10**18) /
                        dividendTotal;
                    currentWeight = currentWeight + sendAmount;
                    distribution = distribution + sendAmount;
                    GBTS.safeTransfer(user.provider, sendAmount);
                    user.profits = sendAmount + user.profits;
                    emit distributed(
                        sendAmount,
                        stakers[indexProvider].provider
                    );
                }
            }
            if (indexProvider == 0) {
                stakers[0].provider = address(this);
                indexProvider = stakers.length;
            }
            indexProvider = indexProvider - 1;
        }
    }

    /**
     * @dev External Admin function to adjust for casino Costs, i.e. VRF, developers, raffles ...
     *      When distributed to the new address the address will be readjusted back to the ULP.
     * @param _ulpDivAddr is the address to recieve the dividends
     */
    function changeULPDivs(address _ulpDivAddr) external onlyOwner {
        require(
            stakers[0].provider == address(this),
            "ULP: Need to wait for distribution."
        );
        stakers[0].provider = _ulpDivAddr;
        uint256 feeAmount = stakers[0].shares / 1000; //0.1% fee to change ULP stakes
        stakers[0].shares = stakers[0].shares - feeAmount;
        dividendTotal = dividendTotal - feeAmount;
        _burn(address(this), feeAmount);
        emit dividendPoolAddressChanged(_ulpDivAddr, feeAmount);
    }

    /**
     * @dev External function to unlock game for approval. This can be called by only owner.
     * @param _gameAddr Game Address
     */
    function unlockGameForApproval(address _gameAddr) external onlyOwner {
        require(
            _gameAddr.isContract() == true,
            "ULP: Address is not contract address"
        );
        require(
            gameApprovalLockTimestamp[_gameAddr] == 0,
            "ULP: Game approval unlock already initiated"
        );
        gameApprovalLockTimestamp[_gameAddr] = block.timestamp;

        emit gameApprovalUnlockInitiated(_gameAddr);
    }

    /**
     * @dev External function for changing game's approval. This is called by only owner.
     * @param _gameAddr Address of game
     * @param _approved Approve a game or not
     */

    function changeGameApproval(address _gameAddr, bool _approved)
        external
        onlyOwner
        gameApprovalNotLocked(_gameAddr)
    {
        require(
            _gameAddr.isContract() == true,
            "ULP: Address is not contract address"
        );
        uint256 currentGameIndex = gameIndex[_gameAddr];

        if (approvedGamesList.length > currentGameIndex && approvedGamesList[currentGameIndex] == _gameAddr) {
            address lastGameAddr = approvedGamesList[approvedGamesList.length - 1];
            approvedGamesList[currentGameIndex] = lastGameAddr;
            gameIndex[lastGameAddr] = currentGameIndex;
            approvedGamesList.pop();
        }

        if (_approved == true) {
            gameIndex[_gameAddr] = approvedGamesList.length;
            approvedGamesList.push(_gameAddr);
        }

        gameApprovalLockTimestamp[_gameAddr] = 0;
        isApprovedGame[_gameAddr] = _approved;

        emit gameApproved(_gameAddr, _approved);
    }

    /**
     * @dev External function to get approved games list.
     */
    function getApprovedGamesList() external view returns (address[] memory) {
        return approvedGamesList;
    }

    /**
     * @dev External function to send prize to winner. This is called by only approved games.
     * @param _winner Address of game winner
     * @param _prizeAmount Amount of GBTS token
     */
    function sendPrize(address _winner, uint256 _prizeAmount)
        external
        onlyApprovedGame
    {
        require(
            GBTS.balanceOf(address(this)) >= _prizeAmount,
            "ULP: There is no enough GBTS balance"
        );
        GBTS.safeTransfer(_winner, _prizeAmount);

        emit prizeSent(msg.sender, _winner, _prizeAmount);
    }

    /**
     * @dev Public function to request Chainlink random number from ULP. This function can be called by only apporved games.
     */
    function requestRandomNumber() public onlyApprovedGame returns (bytes32) {
        if (block.number - lastBlockNumber > nextCall) {
            distribute();
            currentRequestId = RNG.requestRandomNumber();
            randomMatch[currentRequestId] = 0;
            hasReturned[currentRequestId] = false;
            lastBlockNumber = block.number;
        }
        return currentRequestId;
    }

    /**
     * @dev Public function to get new vrf number(Game number). This function can be called by only apporved games.
     * @param _requestId Batching Id of random number.
     */
    function getVerifiedRandomNumber(bytes32 _requestId)
        public
        onlyApprovedGame
        returns (uint256)
    {
        if (hasReturned[_requestId]) {
            return randomMatch[_requestId];
        } else {
            uint256 random = RNG.getVerifiedRandomNumber(_requestId); //RNG will revert if it is not returned
            hasReturned[_requestId] = true;
            randomMatch[_requestId] = random;
            return random;
        }
    }

    /**
     * @dev External function to check if the gameAddress is the approved game.
     * @param _gameAddress Game Address
     */
    function currentGameApproved(address _gameAddress)
        external
        view
        returns (bool)
    {
        return isApprovedGame[_gameAddress];
    }

    /**
     * @dev External function to burn sGBTS token. Only called by owner.
     * @param _amount Amount of sGBTS
     */
    function burnULPsGbts(uint256 _amount) external onlyOwner {
        require(stakers[0].shares >= _amount, "ULP: Not enough shares");
        stakers[0].shares = stakers[0].shares - _amount;
        dividendTotal = dividendTotal - _amount;
        _burn(address(this), _amount);
        emit sGBTSburnt(_amount);
    }

    /**
     * @dev External function to change batch block space. Only called by owner.
     * @param _newChange Block space change amount
     */
    function changeBatchBlockSpace(uint256 _newChange) external onlyOwner {
        require(_newChange <= 3, "ULP: The change does not meet the parameters");
        nextCall = _newChange;
        emit batchGroupingChanged(nextCall);
    }
}
