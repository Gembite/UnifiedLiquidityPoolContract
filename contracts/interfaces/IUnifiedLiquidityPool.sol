// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

/**
 * @title UnifiedLiquidityPool Interface
 */
interface IUnifiedLiquidityPool {
    /**
     * @dev External function for start staking. Only owner can call this function.
     * @param _initialStake Amount of GBTS token
     */
    function startStaking(uint256 _initialStake) external;

    /**
     * @dev External function for staking. This function can be called by any users.
     * @param _amount Amount of GBTS token
     */
    function stake(uint256 _amount) external;

    /**
     * @dev External function for exit staking. Users can withdraw their funds.
     * @param _amount Amount of sGBTS token
     */
    function exitStake(uint256 _amount) external;

    /**
     * @dev External function for sending prize to winner. This is called by only approved games.
     * @param _prizeAmount Amount of GBTS token
     */
    function sendPrize(address _winner, uint256 _prizeAmount) external;

    /**
     * @dev External function for approving games. This is called by only owner.
     * @param _gameAddr Address of game
     */
    function approveGame(address _gameAddr, bool _approved) external;

    /**
     * @dev External function for burning sGBTS token. Only called by owner.
     * @param _amount Amount of sGBTS
     */
    function burnULPsGbts(uint256 _amount) external;

    /**
     * @dev External function for getting vrf number and reqeust randomness. This function can be called by only apporved games.
     */
    function getRandomNumber() external returns (uint256);

    /**
     * @dev External function for getting new vrf number(Game number). This function can be called by only apporved games.
     * @param _oldRandom Previous random number
     */
    function getNewRandomNumber(uint256 _oldRandom) external returns (uint256);

    /**
     * @dev Public function for returning verified random number. This function can be called by only approved games.
     */
    function getVerifiedRandomNumber() external view returns (uint256);

    /**
     * @dev External function to return the current NFT distribution address
     */
    function currentNFT() external view returns (address);

    /**
     * @dev External function for checking if the gameAddress is the approved game.
     * @param _gameAddress Game Address
     */
    function approvedGamesList(address _gameAddress) external returns (bool);

    /**
     * @dev External function to set the NFT distribution address. This function can be called by only owner.
     * @param _nftDistAddr Address of new NFT Distribution
     */
    function setNFTAddress(address _nftDistAddr) external;

    /**
     * @dev External function for changing game's approval. This is called by only owner.
     * @param _gameAddr Address of game
     * @param _approved Approve a game or not
     */
    function changeGameApproval(address _gameAddr, bool _approved) external;

    /**
     * @dev External Admin function to adjust for casino Costs, i.e. VRF, developers, raffles ...
     *      When distributed to the new address the address will be readjusted back to the ULP.
     * @param _ulpDivAddr is the address to recieve the dividends
     */
    function changeULPDivs(address _ulpDivAddr) external;

    /**
     * @dev External function to withdraw from the dividendPool.
     * @param _amount Amount of sGBTS
     */
    function removeFromDividendPool(uint256 _amount) external;

    /**
     * @dev External function for getting amount of sGBTS which caller in DividedPool holds.
     */
    function getBalanceofUserHoldInDividendPool() external returns (uint256);

    /**
     * @dev External function that allows sGBTS holder to deposit their token to earn direct deposits of GBTS into their wallets
     * @param _amount Amount of sGBTS
     */
    function addToDividendPool(uint256 _amount) external;

    /**
     * @dev External function to unlock game for approval. This can be called by only owner.
     * @param _gameAddr Game Address
     */
    function unlockGameForApproval(address _gameAddr) external;

    /**
     * @dev External function to check to see if the distributor has any sGBTS then distribute. Only distributes to one provider at a time.
     *      Only if the ULP has more then 45 million GBTS.
     */
    function distribute() external;
}
