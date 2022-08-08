//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract testPstake is ERC20 {

    constructor () public
    ERC20("testPstake", "testPstake"){
        _mint(msg.sender, 1000000e18);
    }


}