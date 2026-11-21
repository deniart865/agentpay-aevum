# Aevum Builder Challenge #1 — Submission Checklist

Deadline: **11 Dec, 15:00 WIB** (08:00 UTC). Judging 12–14 Dec. Pool $1,500 USDT (800/500/200).
Registered: yes (18 Nov). Solo.

## Done
- [x] Foundry project: AgentRegistry8004 (ERC-8004-style identity) + AgentPayMandates
      (per-tx / per-period / total caps, mandatory expiry, payee allowlist,
      instant revocation, memo audit trail) — `~/workspace/aevum/entry/`
- [x] Test suite: 19 tests, `forge build` + `forge test` green (see below)
- [x] Deploy script (`script/Deploy.s.sol`) + end-to-end demo script (`script/demo.sh`)
- [x] README with architecture, workflows, reproduction steps

## Remaining (in order)
1. **GitHub repo (public)** — BLOCKER: no GitHub PAT exists yet. Options:
   Deni creates the repo from his account/phone and pushes, or provides a PAT
   via Secure Vault so the agent can push `~/workspace/aevum/entry/`.
   Suggested repo name: `agentpay-aevum`. Include README.md as-is.
2. **Deploy to Aevum testnet** (chain 44005, RPC https://rpc-test.qday.info):
   - [x] DEDICATED testnet keys created 19 Nov (chmod 600,
     `~/workspace/aevum/testnet-key.json`): deployer/principal
     `0x8B4Dc3c008656dF2073858c300F9C87f9f06E99c`, agent
     `0xCc83c03F6b2e9841E6598A6d1dD0C7c0EaF10ad7`.
   - [x] FUNDED 19 Nov: Deni claimed 5 tQDAY via the faucet site (recipient =
     his mainnet-eligible wallet) and forwarded 4,9 tQDAY to the deployer;
     the deployer then funded the agent with 0,5 tQDAY
     (tx 0x7cd14cfc7161d34884a9069edc19de6762dca027e8dbab5a96e29eafc8487d1c).
   - [x] DEPLOYED 19 Nov (final, Shanghai build — see note below):
     - AgentRegistry8004: `0x85d0d8D5B1A66bcCE9bD9264B2a4cCeC32eAecab`
       (deploy tx 0xf46b4f26ef7816979bc8661d39b7eae4013f03c0464f36563906b1dd0555ddc1)
       https://explorer-test.qday.info/address/0x85d0d8D5B1A66bcCE9bD9264B2a4cCeC32eAecab
     - AgentPayMandates: `0xA7Fa313C1E299F60a9dCf7146FD73ddCADE96b91`
       (deploy tx 0xd9758c92d575d4c8940ad8554d3d553b5a32a09b42c49600986e9c55c3f30918)
       https://explorer-test.qday.info/address/0xA7Fa313C1E299F60a9dCf7146FD73ddCADE96b91
     - MockUSD8 (demo token): `0xDe313Fd80080Eaa55974684320A79212cec50d97`
       (deploy tx 0xf15c2f305162dfa520d1c42e180f4f75816d9a59e80ff1c3493fda83e4d442bb)
       https://explorer-test.qday.info/address/0xDe313Fd80080Eaa55974684320A79212cec50d97
   - [x] VERIFIED: all three contracts source-verified on Blockscout
     (`is_verified = true` for each, checked via the explorer API).
   - [x] DEMO RUN end-to-end 19 Nov (mandate #1, MockUSD8 — substitution
     note below): register agent id 1
     (0x116c64544cd53a87707dfd6e3a4d9050c73b7e6213e436e159b791d90aa2140f) →
     approve (0xe36f969dd2a1cb376ca755a2874825b68b4dc7e62976f8b6616f3e903d9599a8) →
     createMandate 10/tx, 50/day, +7d expiry, anyPayee=false
     (0xd03c8585b730365435320927b5bb2c9aa306f04134634dc9a166d52285177c24) →
     setPayeeAllowed merchant (0x6c3ea94080e589bbfc1ed9941646686f1c6ee299f165d9a39abb37bf1e4b8638) →
     in-cap payment 7 ✓ (0x2a0a60167bb9367f9602d50b0fe2c8429ad1ae152043a31de95e58ee293decb3) →
     over-cap payment 11 reverted `ExceedsPerTxCap` ✓ →
     revoke (0x0c2be22d835ec8bfeb6a671af695bcc63eab72d97fbab065d922687988ca36ba) →
     post-revoke payment reverted `MandateRevokedError` ✓.
     Full record: `~/workspace/aevum/DEPLOY-LOG-2.md`.
   - **MockUSD8 substitution (honest note):** official tUSD8
     (0x456569838f1d43009A91ebA4263147Afd7233483) was NOT used in the demo.
     Its faucet has the same mainnet-holdings eligibility gate as the tQDAY
     faucet and the fresh deployment wallets are ineligible, so no tUSD8
     could be obtained for them. The demo therefore ran against the included
     MockUSD8 (8 decimals). AgentPayMandates takes the token per mandate, so
     the flow is identical against official tUSD8. (Also note: official
     tUSD8 `decimals()` = **6** on-chain, not 8.)
   - **EVM-version note:** the first deployment (Cancun build, registry
     0xD02bDf14…ffb0 / mandates 0x320b2176…77fD) was abandoned because Aevum's
     EVM is pre-Cancun — `executePayment` reverted with `invalid opcode:
     MCOPY`. The project now pins `evm_version = "shanghai"` in foundry.toml
     (tests still 19/19) and the addresses above are the live, verified,
     demo-proven deployment. Full detail in `~/workspace/aevum/DEPLOY-LOG-2.md`.
3. **Demo video (3–5 min)** — walk the demo.sh flow live on the explorer:
   register identity → create mandate → agent payment → caps blocking an
   oversized payment → revocation blocking further payments. (Parent handles.)
4. **Submit on DoraHacks** (hackathon page: https://dorahacks.io/hackathon/qday/detail):
   repo link + deployed addresses + explorer links + video + project
   description (README's problem/solution sections can be pasted).

## Notes
- All contracts must run on Aevum testnet with test tokens only — satisfied by
  design (token is a per-mandate parameter; deploy against official tUSD8).
- Nothing in this project costs real money: testnet gas is faucet-funded.
