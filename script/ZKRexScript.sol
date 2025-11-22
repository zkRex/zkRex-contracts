// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Token} from "../src/token/Token.sol";
import {Script} from "forge-std/Script.sol";


contract ZKRexScript is Script {
    Token public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new Token();

        vm.stopBroadcast();
    }
}
