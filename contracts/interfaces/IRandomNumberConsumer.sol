// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
 * @title RandomNumberConsumer Interface
 */

interface IRandomNumberConsumer {
    /**
     * @dev External function to request randomness and returns request Id. This function can be called by only apporved games.
     */
    function requestRandomNumber() external returns (bytes32);

    /**
     * @dev External function to return verified random number. This function can be called by only ULP.
     * @param _reqeustId Batching Id of random number.
     */
    function getVerifiedRandomNumber(bytes32 _reqeustId)
        external
        view
        returns (uint256);

    /**
     * @dev External function to set ULP address. This function can be called by only owner.
     * @param _ulpAddr Address of ULP
     */
    function setULPAddress(address _ulpAddr) external;
}
