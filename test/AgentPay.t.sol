// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry8004} from "../src/AgentRegistry8004.sol";
import {AgentPayMandates} from "../src/AgentPayMandates.sol";
import {MockUSD8} from "../src/mocks/MockUSD8.sol";

contract AgentRegistry8004Test is Test {
    AgentRegistry8004 internal registry;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        registry = new AgentRegistry8004();
    }

    function testRegisterAssignsSequentialIds() public {
        vm.prank(alice);
        uint256 id1 = registry.register("ipfs://agent-alice.json");
        vm.prank(bob);
        uint256 id2 = registry.register("ipfs://agent-bob.json");

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(registry.totalAgents(), 2);
        assertEq(registry.ownerOf(id1), alice);
        assertEq(registry.agentURI(id2), "ipfs://agent-bob.json");
        assertEq(registry.agentIdOf(alice), id1);
        assertTrue(registry.isRegisteredAgent(id1, alice));
        assertFalse(registry.isRegisteredAgent(id1, bob));
    }

    function testSetAgentURIOnlyByOwner() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://v1.json");

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry8004.NotAgentOwner.selector, id, bob));
        registry.setAgentURI(id, "ipfs://hijacked.json");

        vm.prank(alice);
        registry.setAgentURI(id, "ipfs://v2.json");
        assertEq(registry.agentURI(id), "ipfs://v2.json");
    }

    function testOwnerOfUnknownReverts() public {
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry8004.AgentNotFound.selector, 99));
        registry.ownerOf(99);
    }

    function testTransferAgentMovesOwnership() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://agent.json");

        vm.prank(alice);
        registry.transferAgent(id, bob);

        assertEq(registry.ownerOf(id), bob);
        assertEq(registry.agentIdOf(alice), 0);
        assertEq(registry.agentIdOf(bob), id);
        assertFalse(registry.isRegisteredAgent(id, alice));
        assertTrue(registry.isRegisteredAgent(id, bob));
    }
}

contract AgentPayMandatesTest is Test {
    AgentRegistry8004 internal registry;
    AgentPayMandates internal mandates;
    MockUSD8 internal token;

    address internal principal = makeAddr("principal");
    address internal agent = makeAddr("agent");
    address internal merchant = makeAddr("merchant");
    address internal stranger = makeAddr("stranger");

    uint256 internal agentId;
    uint256 internal constant USD8 = 1e8; // 1 tUSD8 (8 decimals)

    function setUp() public {
        registry = new AgentRegistry8004();
        mandates = new AgentPayMandates(address(registry));
        token = new MockUSD8();

        vm.prank(agent);
        agentId = registry.register("ipfs://agent-card.json");

        token.mint(principal, 1_000 * USD8);
        vm.prank(principal);
        token.approve(address(mandates), type(uint256).max);
    }

    /// Default mandate: 10 tUSD8/tx, 50 tUSD8/day, no total cap, 7-day expiry, any payee.
    function _createDefault() internal returns (uint256 mandateId) {
        vm.prank(principal);
        mandateId = mandates.createMandate(
            agentId,
            agent,
            address(token),
            10 * USD8,
            50 * USD8,
            1 days,
            0,
            uint64(block.timestamp + 7 days),
            true
        );
    }

    function testCreateMandateStoresTerms() public {
        uint256 id = _createDefault();
        AgentPayMandates.Mandate memory m = mandates.getMandate(id);
        assertEq(m.principal, principal);
        assertEq(m.agent, agent);
        assertEq(m.agentId, agentId);
        assertEq(m.token, address(token));
        assertEq(m.perTxCap, 10 * USD8);
        assertEq(m.periodCap, 50 * USD8);
        assertEq(m.totalSpent, 0);
        assertFalse(m.revoked);
        assertEq(mandates.remainingAllowance(id), 50 * USD8);
    }

    function testCreateMandateRequiresRegisteredAgent() public {
        vm.prank(principal);
        vm.expectRevert(
            abi.encodeWithSelector(AgentPayMandates.AgentNotRegistered.selector, agentId, stranger)
        );
        mandates.createMandate(
            agentId, stranger, address(token), 10 * USD8, 50 * USD8, 1 days, 0, uint64(block.timestamp + 7 days), true
        );
    }

    function testCreateMandateRejectsBadTerms() public {
        vm.prank(principal);
        vm.expectRevert(AgentPayMandates.InvalidTerms.selector);
        mandates.createMandate(
            agentId,
            agent,
            address(token),
            60 * USD8, // perTxCap above periodCap
            50 * USD8,
            1 days,
            0,
            uint64(block.timestamp + 7 days),
            true
        );
    }

    function testExecutePaymentMovesFunds() public {
        uint256 id = _createDefault();

        vm.prank(agent);
        mandates.executePayment(id, merchant, 7 * USD8, "api-calls: november batch");

        assertEq(token.balanceOf(merchant), 7 * USD8);
        assertEq(token.balanceOf(principal), 993 * USD8);
        AgentPayMandates.Mandate memory m = mandates.getMandate(id);
        assertEq(m.periodSpent, 7 * USD8);
        assertEq(m.totalSpent, 7 * USD8);
        assertEq(mandates.currentPeriodSpent(id), 7 * USD8);
        assertEq(mandates.remainingAllowance(id), 43 * USD8);
    }

    function testExecuteAbovePerTxCapReverts() public {
        uint256 id = _createDefault();
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(AgentPayMandates.ExceedsPerTxCap.selector, 11 * USD8, 10 * USD8)
        );
        mandates.executePayment(id, merchant, 11 * USD8, "too big");
    }

    function testExecuteAbovePeriodCapReverts() public {
        uint256 id = _createDefault();
        vm.startPrank(agent);
        for (uint256 i = 0; i < 5; i++) {
            mandates.executePayment(id, merchant, 10 * USD8, "batch");
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPayMandates.ExceedsPeriodCap.selector, 50 * USD8, 1 * USD8, 50 * USD8
            )
        );
        mandates.executePayment(id, merchant, 1 * USD8, "one too many");
        vm.stopPrank();
    }

    function testPeriodRolloverResetsAllowance() public {
        uint256 id = _createDefault();
        vm.startPrank(agent);
        for (uint256 i = 0; i < 5; i++) {
            mandates.executePayment(id, merchant, 10 * USD8, "day 1");
        }
        vm.stopPrank();
        assertEq(mandates.currentPeriodSpent(id), 50 * USD8);

        vm.warp(block.timestamp + 1 days + 1);
        assertEq(mandates.currentPeriodSpent(id), 0);
        assertEq(mandates.remainingAllowance(id), 50 * USD8);

        vm.prank(agent);
        mandates.executePayment(id, merchant, 10 * USD8, "day 2");
        assertEq(token.balanceOf(merchant), 60 * USD8);
    }

    function testExecuteAfterExpiryReverts() public {
        uint256 id = _createDefault();
        vm.warp(block.timestamp + 7 days);
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPayMandates.MandateExpired.selector, id, uint64(1 + 7 days)
            )
        );
        mandates.executePayment(id, merchant, 1 * USD8, "too late");
    }

    function testRevokedMandateRevertsAndOnlyPrincipalCanRevoke() public {
        uint256 id = _createDefault();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentPayMandates.NotPrincipal.selector, id, stranger));
        mandates.revokeMandate(id);

        vm.prank(principal);
        mandates.revokeMandate(id);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentPayMandates.MandateRevokedError.selector, id));
        mandates.executePayment(id, merchant, 1 * USD8, "revoked");
    }

    function testNonAgentCannotExecute() public {
        uint256 id = _createDefault();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentPayMandates.NotAgent.selector, id, stranger));
        mandates.executePayment(id, merchant, 1 * USD8, "not the agent");
    }

    function testPayeeAllowlistEnforced() public {
        vm.prank(principal);
        uint256 id = mandates.createMandate(
            agentId, agent, address(token), 10 * USD8, 50 * USD8, 1 days, 0, uint64(block.timestamp + 7 days), false
        );

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentPayMandates.PayeeNotAllowed.selector, id, merchant));
        mandates.executePayment(id, merchant, 1 * USD8, "not listed");

        vm.prank(principal);
        mandates.setPayeeAllowed(id, merchant, true);

        vm.prank(agent);
        mandates.executePayment(id, merchant, 1 * USD8, "listed merchant");
        assertEq(token.balanceOf(merchant), 1 * USD8);
    }

    function testTotalCapEnforcedAcrossPeriods() public {
        vm.prank(principal);
        uint256 id = mandates.createMandate(
            agentId,
            agent,
            address(token),
            10 * USD8,
            50 * USD8,
            1 days,
            120 * USD8, // lifetime cap
            uint64(block.timestamp + 30 days),
            true
        );

        vm.startPrank(agent);
        for (uint256 day = 0; day < 2; day++) {
            for (uint256 i = 0; i < 5; i++) {
                mandates.executePayment(id, merchant, 10 * USD8, "spend");
            }
            vm.warp(block.timestamp + 1 days + 1);
        }
        mandates.executePayment(id, merchant, 10 * USD8, "spend");
        mandates.executePayment(id, merchant, 10 * USD8, "spend");
        // 120 tUSD8 total spent; the next payment must hit the total cap.
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPayMandates.ExceedsTotalCap.selector, 120 * USD8, 1 * USD8, 120 * USD8
            )
        );
        mandates.executePayment(id, merchant, 1 * USD8, "over the lifetime cap");
        vm.stopPrank();
    }

    function testIdentityTransferStopsPayments() public {
        uint256 id = _createDefault();
        vm.prank(agent);
        registry.transferAgent(agentId, stranger);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(AgentPayMandates.AgentNotRegistered.selector, agentId, agent)
        );
        mandates.executePayment(id, merchant, 1 * USD8, "identity moved");
    }

    function testPaymentFailsWithoutTokenAllowance() public {
        uint256 id = _createDefault();
        vm.prank(principal);
        token.approve(address(mandates), 0);

        vm.prank(agent);
        vm.expectRevert(AgentPayMandates.TransferFailed.selector);
        mandates.executePayment(id, merchant, 1 * USD8, "no allowance");
    }

    function testZeroAmountReverts() public {
        uint256 id = _createDefault();
        vm.prank(agent);
        vm.expectRevert(AgentPayMandates.ZeroAmount.selector);
        mandates.executePayment(id, merchant, 0, "nothing");
    }
}
