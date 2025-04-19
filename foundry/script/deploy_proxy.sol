// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {Proxy} from "@src/aave/Proxy.sol";

contract DeployProxyScript is Script {
    function run() public {
        vm.startBroadcast();
        // console.log("msg.sender", msg.sender);
        new Proxy(msg.sender);
        vm.stopBroadcast();
    }
}
