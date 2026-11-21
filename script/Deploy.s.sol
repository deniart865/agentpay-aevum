// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AgentRegistry8004} from "../src/AgentRegistry8004.sol";
import {AgentPayMandates} from "../src/AgentPayMandates.sol";

/// @notice Deploys the AgentPay stack to Aevum testnet (chain 44005).
/// Usage:
///   export PRIVATE_KEY=<dedicated testnet key, funded with tQDAY from faucet.qday.info>
///   forge script script/Deploy.s.sol --rpc-url aevum --broadcast
/// Then verify (Blockscout):
///   forge verify-contract --chain-id 44005 --verifier blockscout \
///     --verifier-url https://explorer-test.qday.info/api \
///     <ADDRESS> src/AgentRegistry8004.sol:AgentRegistry8004
///   (same for AgentPayMandates, with --constructor-args for the registry address)
contract Deploy is Script {
    /// @notice Official tUSD8 on Aevum testnet (QDay wiki, official contract
    ///         addresses; confirmed on the Aevum explorer). The mandates
    ///         contract itself is token-agnostic — tUSD8 is passed per mandate
    ///         at creation time, so nothing to configure here.
    address public constant TUSD8_AEVUM = 0x456569838f1d43009A91ebA4263147Afd7233483;

    function run() external {
        vm.startBroadcast();
        AgentRegistry8004 registry = new AgentRegistry8004();
        AgentPayMandates mandates = new AgentPayMandates(address(registry));
        vm.stopBroadcast();

        console.log("AgentRegistry8004:", address(registry));
        console.log("AgentPayMandates: ", address(mandates));
        console.log("tUSD8 (Aevum):    ", TUSD8_AEVUM);
    }
}
