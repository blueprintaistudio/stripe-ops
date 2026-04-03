#!/usr/bin/env bash
# stripe-health-check.sh
# Verify Stripe CLI auth, API connectivity, and show account info.
# Usage: ./stripe-health-check.sh [--api-key sk_test_...]

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $*"; }
fail() { echo -e "${RED}✗${RESET} $*"; }
info() { echo -e "${CYAN}→${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $*"; }
section() { echo -e "\n${BOLD}$*${RESET}"; echo "$(printf '─%.0s' {1..50})"; }

# ─── Parse args ───────────────────────────────────────────────────────────────
API_KEY_FLAG=""
if [[ "${1:-}" == "--api-key" && -n "${2:-}" ]]; then
  API_KEY_FLAG="--api-key $2"
fi

# ─── 1. CLI Installed ──────────────────────────────────────────────────────────
section "1. Stripe CLI"
if command -v stripe &>/dev/null; then
  VERSION=$(stripe version 2>/dev/null || echo "unknown")
  ok "stripe CLI found: ${VERSION}"
else
  fail "stripe CLI not found"
  echo ""
  warn "Install it with:"
  echo "    brew install stripe/stripe-cli/stripe"
  exit 1
fi

# ─── 2. Auth Check ────────────────────────────────────────────────────────────
section "2. Authentication"
if [[ -n "$API_KEY_FLAG" ]]; then
  info "Using provided --api-key flag"
  STRIPE_CMD="stripe $API_KEY_FLAG"
else
  # Check if logged in via stripe login
  CONFIG_FILE="$HOME/.config/stripe/config.toml"
  if [[ -f "$CONFIG_FILE" ]]; then
    ok "Config file found: $CONFIG_FILE"
    STRIPE_CMD="stripe"
  else
    warn "No config file at $CONFIG_FILE — may not be logged in"
    info "Run: stripe login"
    STRIPE_CMD="stripe"
  fi
fi

# ─── 3. API Connectivity ──────────────────────────────────────────────────────
section "3. API Connectivity"
info "Testing API connection..."
if BALANCE_JSON=$(eval "$STRIPE_CMD balance retrieve" 2>&1); then
  ok "API connection successful"
else
  fail "API connection failed"
  echo ""
  echo "$BALANCE_JSON"
  echo ""
  warn "If you see 'No such API key', run: stripe login"
  warn "Or pass: $0 --api-key sk_test_YOUR_KEY"
  exit 1
fi

# ─── 4. Account Info ──────────────────────────────────────────────────────────
section "4. Account Info"
if ACCOUNT_JSON=$(eval "$STRIPE_CMD get /v1/account" 2>&1); then
  # Extract fields using grep/sed for portability (no jq required)
  ACCT_ID=$(echo "$ACCOUNT_JSON"      | grep '"id"'          | head -1 | sed 's/.*"id": "\([^"]*\)".*/\1/')
  ACCT_EMAIL=$(echo "$ACCOUNT_JSON"   | grep '"email"'       | head -1 | sed 's/.*"email": "\([^"]*\)".*/\1/')
  ACCT_NAME=$(echo "$ACCOUNT_JSON"    | grep '"display_name"'| head -1 | sed 's/.*"display_name": "\([^"]*\)".*/\1/')
  COUNTRY=$(echo "$ACCOUNT_JSON"      | grep '"country"'     | head -1 | sed 's/.*"country": "\([^"]*\)".*/\1/')
  CHARGES_EN=$(echo "$ACCOUNT_JSON"   | grep '"charges_enabled"' | head -1 | sed 's/.*"charges_enabled": \([a-z]*\).*/\1/')
  PAYOUTS_EN=$(echo "$ACCOUNT_JSON"   | grep '"payouts_enabled"' | head -1 | sed 's/.*"payouts_enabled": \([a-z]*\).*/\1/')

  echo "  Account ID      : ${ACCT_ID:-n/a}"
  echo "  Display Name    : ${ACCT_NAME:-n/a}"
  echo "  Email           : ${ACCT_EMAIL:-n/a}"
  echo "  Country         : ${COUNTRY:-n/a}"

  if [[ "$CHARGES_EN" == "true" ]]; then
    ok "Charges enabled"
  else
    warn "Charges NOT enabled (account may need onboarding)"
  fi

  if [[ "$PAYOUTS_EN" == "true" ]]; then
    ok "Payouts enabled"
  else
    warn "Payouts NOT enabled (check Stripe dashboard)"
  fi
else
  fail "Could not retrieve account info"
  echo "$ACCOUNT_JSON"
fi

# ─── 5. Balance Summary ───────────────────────────────────────────────────────
section "5. Balance"
info "Retrieving balance..."
BALANCE_OUT=$(eval "$STRIPE_CMD balance retrieve" 2>&1)

# Detect test mode by checking livemode
if echo "$BALANCE_OUT" | grep -q '"livemode": false'; then
  warn "You are in TEST MODE — no real money"
elif echo "$BALANCE_OUT" | grep -q '"livemode": true'; then
  ok "LIVE MODE — real funds"
fi

# Print available balance entries
AVAIL=$(echo "$BALANCE_OUT" | grep -A3 '"available"' | grep '"amount"' | head -5)
echo ""
echo "  Available balance:"
if [[ -n "$AVAIL" ]]; then
  echo "$AVAIL" | sed 's/.*"amount": \([0-9-]*\).*/    \1 cents/'
else
  echo "    (parse manually — run: stripe balance retrieve)"
fi

# ─── 6. Recent Customers ──────────────────────────────────────────────────────
section "6. Recent Activity"
info "Fetching last 5 customers..."
if CUSTS=$(eval "$STRIPE_CMD customers list --limit 5" 2>&1); then
  CUST_COUNT=$(echo "$CUSTS" | grep '"id": "cus_' | wc -l | tr -d ' ')
  ok "Found ${CUST_COUNT} customer(s) in result"
else
  warn "Could not list customers"
fi

info "Fetching last 5 payment intents..."
if PIS=$(eval "$STRIPE_CMD payment_intents list --limit 5" 2>&1); then
  PI_COUNT=$(echo "$PIS" | grep '"id": "pi_' | wc -l | tr -d ' ')
  ok "Found ${PI_COUNT} payment intent(s) in result"
else
  warn "Could not list payment intents"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
section "Health Check Complete"
ok "Stripe CLI is operational"
info "Run 'stripe --help' or check references/common-workflows.md to get started"
echo ""
