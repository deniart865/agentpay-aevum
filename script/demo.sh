#!/usr/bin/env bash
# End-to-end demo of AgentPay on Aevum testnet (chain 44005).
#
# Prerequisites:
#   - Contracts deployed (script/Deploy.s.sol) -> set REGISTRY and MANDATES below.
#   - Two dedicated testnet keys, both funded with tQDAY from https://faucet.qday.info
#       PRINCIPAL_PK : the funder wallet (holds tUSD8, grants the mandate)
#       AGENT_PK     : the agent wallet (registers an identity, executes payments)
#   - Principal holds some tUSD8 (test stablecoin
#     0x456569838f1d43009A91ebA4263147Afd7233483 on Aevum).
#
# Flow shown: register agent identity -> approve tUSD8 -> create mandate
# (10 tUSD8/tx, 50 tUSD8/day, 7 days) -> agent pays a merchant 7 tUSD8 ->
# balances + mandate counters -> principal revokes -> agent payment now fails.
set -euo pipefail

RPC="https://rpc-test.qday.info"
TUSD8="0x456569838f1d43009A91ebA4263147Afd7233483"
REGISTRY="${REGISTRY:?set REGISTRY to the deployed AgentRegistry8004 address}"
MANDATES="${MANDATES:?set MANDATES to the deployed AgentPayMandates address}"
: "${PRINCIPAL_PK:?set PRINCIPAL_PK}"
: "${AGENT_PK:?set AGENT_PK}"

PRINCIPAL=$(cast wallet address "$PRINCIPAL_PK")
AGENT=$(cast wallet address "$AGENT_PK")
MERCHANT="${MERCHANT:-0x000000000000000000000000000000000000dEaD}"
USD8="${USD8:-100000000}" # base units per token: MockUSD8 = 1e8 (8 decimals).
# NOTE: official tUSD8 reports 6 decimals on-chain -> set USD8=1000000 when
# running this script against the official token instead of MockUSD8.

echo "Principal: $PRINCIPAL"
echo "Agent:     $AGENT"

echo "== 1. Agent registers its ERC-8004-style identity =="
cast send "$REGISTRY" "register(string)" "ipfs://agentpay-demo-card.json" \
  --rpc-url "$RPC" --private-key "$AGENT_PK"
AGENT_ID=$(cast call "$REGISTRY" "agentIdOf(address)(uint256)" "$AGENT" --rpc-url "$RPC")
echo "Agent id: $AGENT_ID"

echo "== 2. Principal approves tUSD8 spending by the mandates contract =="
cast send "$TUSD8" "approve(address,uint256)" "$MANDATES" $((1000 * USD8)) \
  --rpc-url "$RPC" --private-key "$PRINCIPAL_PK"

echo "== 3. Principal creates a scoped mandate (10/tx, 50/day, expires in 7 days) =="
EXPIRY=$(( $(date +%s) + 7 * 24 * 3600 ))
cast send "$MANDATES" \
  "createMandate(uint256,address,address,uint256,uint256,uint256,uint256,uint64,bool)" \
  "$AGENT_ID" "$AGENT" "$TUSD8" $((10 * USD8)) $((50 * USD8)) 86400 0 "$EXPIRY" true \
  --rpc-url "$RPC" --private-key "$PRINCIPAL_PK"
MANDATE_ID=1

echo "== 4. Agent pays the merchant 7 tUSD8 under the mandate =="
cast send "$MANDATES" "executePayment(uint256,address,uint256,string)" \
  "$MANDATE_ID" "$MERCHANT" $((7 * USD8)) "demo: api-calls november batch" \
  --rpc-url "$RPC" --private-key "$AGENT_PK"

echo "Merchant tUSD8 balance:"
cast call "$TUSD8" "balanceOf(address)(uint256)" "$MERCHANT" --rpc-url "$RPC"
echo "Remaining mandate allowance:"
cast call "$MANDATES" "remainingAllowance(uint256)(uint256)" "$MANDATE_ID" --rpc-url "$RPC"

echo "== 5. Principal revokes the mandate; further agent payments must fail =="
cast send "$MANDATES" "revokeMandate(uint256)" "$MANDATE_ID" \
  --rpc-url "$RPC" --private-key "$PRINCIPAL_PK"
cast send "$MANDATES" "executePayment(uint256,address,uint256,string)" \
  "$MANDATE_ID" "$MERCHANT" $((1 * USD8)) "demo: should revert" \
  --rpc-url "$RPC" --private-key "$AGENT_PK" || echo "OK: payment reverted after revocation"

echo "Demo complete. Verify every step on https://explorer-test.qday.info"
