// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GBTS is ERC20 {
    constructor() ERC20("GemBites", "GBTS") {
        _mint(msg.sender, 100000000 * 10**18);
    }
}
