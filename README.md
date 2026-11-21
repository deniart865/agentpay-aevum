# AgentPay — Scoped Stablecoin Payment Mandates for AI Agents

**Aevum Builder Challenge #1** · Aevum Testnet (QDay) · Solidity / Foundry

## The problem

AI agents increasingly need to *pay* — for API calls, compute, data, and other
agents' services. Today the practical options are both bad:

1. **Give the agent a funded wallet.** A compromised key or a prompt-injected
   agent can drain everything, instantly.
2. **Approve per payment by hand.** Safe, but it destroys the autonomy that
   makes agents useful.

Card networks solved this for humans decades ago with credit limits, daily
caps, merchant restrictions, and instant card freezes. AgentPay brings the
same control model on-chain for agent stablecoin payments on Aevum.

## The solution

A principal (a human or company wallet) grants **one registered agent** a
**payment mandate**: a smart-contract-enforced spending scope for tUSD8, the
Aevum testnet stablecoin. The agent can then pay autonomously — but only
inside the scope:

| Control | Meaning |
| --- | --- |
| Per-transaction cap | No single payment may exceed it |
| Per-period cap | Rolling budget window (e.g. 50 tUSD8 per day) |
| Total cap (optional) | Lifetime ceiling for the mandate |
| Mandatory expiry | Mandates are sessions; they always die |
| Payee allowlist (optional) | Agent may pay only listed merchants |
| Instant revocation | Principal kills the mandate in one transaction |
| Identity binding | Mandate is tied to an ERC-8004-style agent identity, not just an address |

The agent **never custodies funds**. Payments are pulled directly from the
principal's balance via ERC-20 `transferFrom`, so the principal keeps full
sovereignty — and holds a second kill switch (revoking the token allowance
itself). Even a fully compromised agent key can lose at most the remaining
capped budget, never the wallet.

Every payment emits an event carrying a free-text memo, producing a complete,
verifiable on-chain audit trail: which agent paid whom, how much, and why.

## Architecture

```
Principal wallet ──creates mandate──► AgentPayMandates ──transferFrom──► Merchant
      │                                      ▲   │
      │ approves tUSD8                       │   │ checks identity
      ▼                                      │   ▼
   tUSD8 (ERC-20)                            │  AgentRegistry8004
                                             │   (ERC-8004-style identity)
Agent wallet ──executePayment(memo)──────────┘
```

- **`src/AgentRegistry8004.sol`** — minimal ERC-8004-style identity registry.
  Agents register once, receive a sequential `agentId`, and publish an
  agent-card URI. The canonical ERC-8004 registries are not yet deployed on
  Aevum (the QDay FAQ lists agent registration tooling as "coming"), so this
  contract implements the same interface surface the payment layer consumes;
  migrating to the canonical registry later is a constructor-argument change.
- **`src/AgentPayMandates.sol`** — the mandate engine described above.
  Checks-effects-interactions, a reentrancy guard, and safe ERC-20 handling
  (tolerates non-standard tokens that return no bool).
- **`src/mocks/MockUSD8.sol`** — test-only 8-decimal ERC-20 mirroring tUSD8,
  used by the test suite. Never for mainnet.

### Core workflow

1. Agent registers: `AgentRegistry8004.register(agentCardURI)` → `agentId`.
2. Principal approves tUSD8 to `AgentPayMandates` (standard ERC-20 approval).
3. Principal creates the mandate:
   `createMandate(agentId, agent, tUSD8, perTxCap, periodCap, periodLength, totalCap, expiresAt, anyPayee)`.
4. Agent pays: `executePayment(mandateId, payee, amount, memo)` — the contract
   validates identity, caps, period window, expiry, and allowlist, then pulls
   the funds principal → payee and logs the memo.
5. Principal supervises with `getMandate`, `currentPeriodSpent`,
   `remainingAllowance`, and can `revokeMandate` at any time.

## Aevum integration

- **Network:** Aevum Testnet, chain ID **44005**, RPC `https://rpc-test.qday.info`,
  explorer `https://explorer-test.qday.info` (Blockscout).
- **Payment asset:** tUSD8, `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals on-chain — `decimals()` verified live; the name suggests 8, the chain says 6).
- **Gas:** tQDAY from the free faucet at <https://faucet.qday.info>.
- Contracts are token-agnostic: the payment token is a per-mandate parameter,
  so the same code runs against tUSD8 on testnet and USD8 at mainnet launch.

## Quick start

```bash
forge build
forge test        # 19 tests: registry + mandate caps, rollover, expiry,
                  # revocation, allowlist, identity transfer, failure modes
```

### Deploy to Aevum testnet

```bash
export PRIVATE_KEY=<dedicated testnet key funded with tQDAY>
forge script script/Deploy.s.sol --rpc-url aevum --broadcast

forge verify-contract --chain-id 44005 --verifier blockscout \
  --verifier-url https://explorer-test.qday.info/api \
  <REGISTRY_ADDRESS> src/AgentRegistry8004.sol:AgentRegistry8004
```

### Run the end-to-end demo

See `script/demo.sh` — registers an agent, creates a mandate
(10 tUSD8/tx, 50 tUSD8/day, 7-day expiry), executes a 7 tUSD8 payment, then
revokes the mandate and shows further payments reverting.

## Deployment (Aevum testnet)

| Contract | Address | Explorer |
| --- | --- | --- |
| AgentRegistry8004 | `0x85d0d8D5B1A66bcCE9bD9264B2a4cCeC32eAecab` | https://explorer-test.qday.info/address/0x85d0d8D5B1A66bcCE9bD9264B2a4cCeC32eAecab |
| AgentPayMandates | `0xA7Fa313C1E299F60a9dCf7146FD73ddCADE96b91` | https://explorer-test.qday.info/address/0xA7Fa313C1E299F60a9dCf7146FD73ddCADE96b91 |
| MockUSD8 (demo token) | `0xDe313Fd80080Eaa55974684320A79212cec50d97` | https://explorer-test.qday.info/address/0xDe313Fd80080Eaa55974684320A79212cec50d97 |
| tUSD8 (official) | `0x456569838f1d43009A91ebA4263147Afd7233483` | https://explorer-test.qday.info |

All three deployed contracts are source-verified on the explorer. The live
demo ran against MockUSD8 (8 decimals, public mint, test-only): the official
tUSD8 could not be faucet-claimed for the deployment wallets (its faucet gate
requires the recipient to hold ETH/USDT/USDC on Ethereum mainnet, which fresh
testnet wallets fail). AgentPayMandates is token-agnostic — the token is a
per-mandate parameter — so the identical flow runs against official tUSD8
unchanged. Note: the chain's EVM is pre-Cancun, so the project builds with
`evm_version = "shanghai"` (see foundry.toml).

## Security notes

- Least privilege by construction: caps, expiry, allowlist, revocation.
- Identity transfer immediately disables spending under existing mandates
  (ownership is re-checked on every payment).
- No custody, no admin keys, no upgradeability — the deployed code is final.
- Known constraint: mandates rely on the principal's ERC-20 allowance; if the
  allowance is lower than the mandate caps, payments fail with
  `TransferFailed` rather than partially executing.

## Roadmap

- Migrate identity to the canonical ERC-8004 registries when QDay ships them.
- x402 facilitator integration: mandate-checked pay-per-request API payments.
- ERC-4337 smart-account session keys mirroring mandate scopes off-chain.
- Recurring-payment helper (subscription templates on top of mandates).

## License

MIT
