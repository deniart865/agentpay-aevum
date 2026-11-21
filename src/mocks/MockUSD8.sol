// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockUSD8
/// @notice Test-only ERC-20 with 8 decimals mirroring tUSD8 (Aevum testnet's
///         test stablecoin). Used by the local test suite and for fork-free
///         demos. On Aevum testnet the real tUSD8 is at
///         0x456569838f1d43009A91ebA4263147Afd7233483 — deploy AgentPayMandates
///         against that address instead of this mock.
/// @dev Public mint is intentional and safe here: this token has no value and
///      must never be deployed to a mainnet.
contract MockUSD8 {
    string public constant name = "tUSD8 (Mock)";
    string public constant symbol = "tUSD8";
    uint8 public constant decimals = 8;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "INSUFFICIENT_ALLOWANCE");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "INSUFFICIENT_BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
