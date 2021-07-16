// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title RandomNumberConsumer Interface
 */

interface IRandomNumberConsumer {
    /**
     * @dev Public function for request randomness from a user-provided seed and returns request Id. This function can be called by only apporved games.
     * @param _userProvidedSeed Number of seed. Any number can be.
     */
    function requestRandomNumber(uint256 _userProvidedSeed)
        external
        returns (bytes32);

    /**
     * @dev Public function for returning verified random number. This function can be called by only ULP.
     */
    function getVerifiedRandomNumber() external view returns (uint256);

    /**
     * @dev Public function for setting ULP address. This function can be called by only owner.
     * @param _ulpAddr Address of ULP
     */
    function setULPAddress(address _ulpAddr) external;
}
