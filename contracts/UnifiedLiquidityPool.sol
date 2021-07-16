// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IRandomNumberConsumer.sol";

/**
 * @title UnifiedLiquidityPool Contract
 */

contract UnifiedLiquidityPool is ERC20, Ownable, ReentrancyGuard {
    using Address for address;

    /// @notice Event emitted only on construction.
    event UnifiedLiquidityPoolDeployed();

    /// @notice Event emitted when only burn sGBTS token
    event sGBTSburnt(uint256 sGBTSAmount);

    /// @notice Event emitted when change the jackPot Address
    event jackPotChanged(address jackAddress);

    /// @notice Event emitted when change the RNG Address
    event RNGChanged(address rngAddr);

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

    /// @notice Event emitted when prize is sent to the winner
    event prizeSent(address gameAddr, address winner, uint256 GBTSAmount);

    /// @notice Event emitted when game unlock is initiated
    event gameApprovalUnlockInitiated(address gameAddr);

    /// @notice Event emitted when game is approved
    event gameApproved(address gameAddr, bool approved);

    /// @notice NFT address set
    event nftSet(address NFT);

    struct dividendPool {
        address provider;
        uint256 shares;
        uint256 profits;
    }

    /// @notice Approved Game List
    mapping(address => bool) public approvedGames;

    /// @notice GBTS token instance
    IERC20 public GBTS;

    /// @notice Random Number Consumer instance
    IRandomNumberConsumer public RNG;

    /// @notice Address of NFT distribution
    address public NFTaddress;

    /// @notice Boolean variable for checking whether staking is started or not
    bool public isStakingStarted;

    /// @notice Address of jackPot
    address public jackPotAddress;

    /// @notice Weight of current distribution amount
    uint256 public currentWeight;

    /// @notice Stakers array in dividend pool
    dividendPool[] public stakers;

    /// @notice Track the provider index in dividend pool
    mapping(address => uint256) public providerIndex;

    /// @notice Point the next receipent in dividend pool
    uint256 public indexProvider;

    /// @notice Amount of limit can be distributed
    uint256 public balanceControlULP = 45000000 * 10**18;

    /// @notice Distribution weight
    uint256 public distribution;

    uint256 private currentRandom;

    uint256 private constant APPROVAL_TIMELOCK = 1 days;

    mapping(address => uint256) public gameApprovalLockTimestamp;

    mapping(uint256 => uint256) private randomNumbers;

    modifier canStake() {
        require(isStakingStarted, "ULP: Owner must initialize staking");
        _;
    }

    modifier onlyApprovedGame() {
        require(approvedGames[msg.sender], "ULP: Game is not approved");
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
    }

    /**
     * @dev External function for adding or changing JackPot Address.
     * @param _jpAddress Address of JackPot
     */
    function changeJackPot(address _jpAddress) external onlyOwner {
        require(
            _jpAddress.isContract() == true,
            "ULP: This is not a Contract Address"
        );
        jackPotAddress = _jpAddress;

        emit jackPotChanged(_jpAddress);
    }

    /**
     * @dev External function for start staking. Only owner can call this function.
     * @param _initialStake Amount of GBTS token
     */
    function startStaking(uint256 _initialStake) external onlyOwner {
        require(!isStakingStarted, "ULP: FAIL");

        require(
            GBTS.balanceOf(msg.sender) >= _initialStake,
            "ULP: Caller has not enough balance"
        );

        require(
            GBTS.transferFrom(msg.sender, address(this), _initialStake),
            "ULP: Transfer failed"
        );

        _mint(address(this), _initialStake);

        isStakingStarted = true;
        stakers.push(dividendPool(address(this), _initialStake, 0));

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

        require(
            GBTS.transferFrom(msg.sender, address(this), _amount),
            "ULP: Transfer failed"
        );

        _mint(msg.sender, sGBTSAmount);

        emit staked(msg.sender, _amount, sGBTSAmount);
    }

    /**
     * @dev External function for exit staking. Users can withdraw their funds.
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

        require(GBTS.transfer(msg.sender, toSend), "ULP: Transfer Failed");

        if (totalSupply() == 0) {
            isStakingStarted = false;
        }

        emit stakeExit(msg.sender, toSend, _amount);
    }

    /**
     * @dev External function that allows sGBTS holder to deposit their token to earn direct deposits of GBTS into their wallets
     * @param _amount Amount of sGBTS
     */
    function addToDividendPool(uint256 _amount) external {
        require(
            balanceOf(msg.sender) >= _amount,
            "ULP: Caller has not enough balance"
        );

        require(transfer(address(this), _amount), "ULP: Transfer failed");

        uint256 index = providerIndex[msg.sender];

        if (stakers[index].provider == msg.sender) {
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
                        totalSupply();
                    currentWeight = currentWeight + sendAmount;
                    distribution = distribution + sendAmount;
                    require(
                        GBTS.transfer(user.provider, sendAmount),
                        "ULP: Staker didn't receive profits"
                    );
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
        _burn(address(this), feeAmount);
        emit sGBTSburnt(feeAmount);
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
        approvedGames[_gameAddr] = _approved;

        emit gameApproved(_gameAddr, _approved);
    }

    /**
     * @dev External function for sending prize to winner. This is called by only approved games.
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
        require(GBTS.transfer(_winner, _prizeAmount), "ULP: Transfer failed");

        emit prizeSent(msg.sender, _winner, _prizeAmount);
    }

    /**
     * @dev Public function for getting vrf number and reqeust randomness. This function can be called by only apporved games.
     */
    function getRandomNumber() public onlyApprovedGame returns (uint256) {
        uint256 rand = RNG.getVerifiedRandomNumber();
        if (currentRandom != rand || (currentRandom == 0 && rand == 0)) {
            distribute();
            randomNumbers[currentRandom] = rand;
            currentRandom = rand;
            RNG.requestRandomNumber(2021);
        }
        return currentRandom;
    }

    /**
     * @dev Public function for getting new vrf number(Game number). This function can be called by only apporved games.
     * @param _oldRandom Previous random number
     */
    function getNewRandomNumber(uint256 _oldRandom)
        public
        onlyApprovedGame
        returns (uint256)
    {
        require(
            _oldRandom != getRandomNumber(),
            "ULP: Current game is not time to play"
        );
        return randomNumbers[_oldRandom];
    }

    /**
     * @dev External function to set the NFT distribution address. This function can be called by only owner.
     * @param _nftDistAddr Address of new NFT Distribution
     */
    function setNFTAddress(address _nftDistAddr) external onlyOwner {
        NFTaddress = _nftDistAddr;
        emit nftSet(_nftDistAddr);
    }

    /**
     * @dev External function for checking if the gameAddress is the approved game.
     * @param _gameAddress Game Address
     */
    function approvedGamesList(address _gameAddress)
        external
        view
        returns (bool)
    {
        return approvedGames[_gameAddress];
    }

    /**
     * @dev External function to return the current NFT distribution address
     */
    function currentNFT() external view returns (address) {
        return address(NFTaddress);
    }

    /**
     * @dev External function for burning sGBTS token. Only called by owner.
     * @param _amount Amount of sGBTS
     */
    function burnULPsGbts(uint256 _amount) external onlyOwner {
        require(stakers[0].shares >= _amount, "ULP: Not enough shares");
        stakers[0].shares = stakers[0].shares - _amount;

        emit sGBTSburnt(_amount);
    }
}
