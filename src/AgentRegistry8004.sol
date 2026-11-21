// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title AgentRegistry8004
/// @notice Minimal ERC-8004-style agent identity registry for the Aevum testnet.
/// @dev The canonical ERC-8004 registries are not yet deployed on Aevum (the QDay
///      FAQ lists agent registration tooling as "coming"), so this contract ships a
///      faithful minimal implementation of the ERC-8004 Identity Registry surface:
///      an agent registers once, receives a sequential agentId, and publishes an
///      agent-card URI (name, description, endpoints, capabilities). Payment
///      contracts (see AgentPayMandates) bind spending mandates to these
///      identities instead of to bare addresses, and can migrate to the canonical
///      registry unchanged because the consumed interface is identical.
contract AgentRegistry8004 {
    struct Agent {
        address owner;
        string uri;
        bool exists;
    }

    /// @notice Next agent id to assign. Ids start at 1; 0 means "no agent".
    uint256 public nextAgentId = 1;

    mapping(uint256 => Agent) private _agents;

    /// @notice First agent id registered by an owner (0 if none).
    mapping(address => uint256) public agentIdOf;

    event Registered(uint256 indexed agentId, address indexed owner, string uri);
    event AgentURIUpdated(uint256 indexed agentId, string uri);
    event AgentTransferred(uint256 indexed agentId, address indexed from, address indexed to);

    error AgentNotFound(uint256 agentId);
    error NotAgentOwner(uint256 agentId, address caller);
    error ZeroAddress();

    /// @notice Register a new agent identity for the caller.
    /// @param uri URI of the agent card (JSON metadata: name, description, endpoints).
    /// @return agentId The newly assigned agent id.
    function register(string calldata uri) external returns (uint256 agentId) {
        agentId = nextAgentId++;
        _agents[agentId] = Agent({owner: msg.sender, uri: uri, exists: true});
        if (agentIdOf[msg.sender] == 0) {
            agentIdOf[msg.sender] = agentId;
        }
        emit Registered(agentId, msg.sender, uri);
    }

    /// @notice Update the agent-card URI. Only the agent owner may call this.
    function setAgentURI(uint256 agentId, string calldata uri) external {
        Agent storage agent = _get(agentId);
        if (agent.owner != msg.sender) revert NotAgentOwner(agentId, msg.sender);
        agent.uri = uri;
        emit AgentURIUpdated(agentId, uri);
    }

    /// @notice Transfer an agent identity to a new owner wallet.
    /// @dev Payment mandates bound to this identity check `ownerOf` at execution
    ///      time, so transferring an identity immediately stops its old wallet
    ///      from spending under existing mandates.
    function transferAgent(uint256 agentId, address to) external {
        if (to == address(0)) revert ZeroAddress();
        Agent storage agent = _get(agentId);
        if (agent.owner != msg.sender) revert NotAgentOwner(agentId, msg.sender);
        if (agentIdOf[msg.sender] == agentId) {
            agentIdOf[msg.sender] = 0;
        }
        agent.owner = to;
        if (agentIdOf[to] == 0) {
            agentIdOf[to] = agentId;
        }
        emit AgentTransferred(agentId, msg.sender, to);
    }

    /// @notice Owner wallet of an agent identity. Reverts for unknown ids.
    function ownerOf(uint256 agentId) public view returns (address) {
        return _get(agentId).owner;
    }

    /// @notice Agent-card URI of an agent identity. Reverts for unknown ids.
    function agentURI(uint256 agentId) external view returns (string memory) {
        return _get(agentId).uri;
    }

    /// @notice True if `agentId` exists and is currently owned by `account`.
    function isRegisteredAgent(uint256 agentId, address account) external view returns (bool) {
        Agent storage agent = _agents[agentId];
        return agent.exists && agent.owner == account;
    }

    /// @notice Total number of registered agent identities.
    function totalAgents() external view returns (uint256) {
        return nextAgentId - 1;
    }

    function _get(uint256 agentId) internal view returns (Agent storage agent) {
        agent = _agents[agentId];
        if (!agent.exists) revert AgentNotFound(agentId);
    }
}
