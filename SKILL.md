---
name: stripe-ops
description: >
  Comprehensive Stripe payment operations via the Stripe CLI. Use when managing
  payments, subscriptions, customers, invoices, refunds, products, prices,
  payment links, checkout sessions, webhooks, disputes, or balance/payouts.
  Triggers on: "create a payment link", "charge a customer", "set up a
  subscription", "send an invoice", "issue a refund", "create a product",
  "check Stripe balance", "listen for webhooks", "manage disputes", "create
  checkout session", "stripe", "billing", "subscription management".
---

# stripe-ops

Manage Stripe operations via the `stripe` CLI. Covers the full payment lifecycle
for freelancers, SaaS builders, and agencies.

## Prerequisites

Verify `stripe` CLI is installed:

```bash
stripe version
```

If not found, install it:

```bash
brew install stripe/stripe-cli/stripe
```

Authenticate (one-time per machine):

```bash
stripe login
```

Or pass `--api-key sk_test_...` / `--api-key sk_live_...` to any command to
skip login. Use `sk_test_` keys for test mode; `sk_live_` for production.

> **Test vs Live:** Prefix keys with `sk_test_` for safe sandbox testing.
> All test-mode objects are isolated and never charge real cards.

---

## 1. Products & Prices

Products describe what you sell. Prices define cost and billing cadence.
**Always create a Product before creating a Price.**

### Create a product

```bash
stripe products create \
  --name "Pro Plan" \
  --description "Full access to all features"
```

### Create a one-time price

```bash
stripe prices create \
  --product prod_XXXX \
  --unit-amount 4900 \
  --currency usd
```

### Create a recurring price (monthly)

```bash
stripe prices create \
  --product prod_XXXX \
  --unit-amount 2900 \
  --currency usd \
  --recurring[interval]=month
```

### List products and prices

```bash
stripe products list --limit 20
stripe prices list --product prod_XXXX --limit 20
```

---

## 2. Payment Links

Payment Links are shareable hosted checkout URLs — no code required.

### Create a payment link (one-time)

```bash
stripe payment_links create \
  --line-items[0][price]=price_XXXX \
  --line-items[0][quantity]=1
```

### Create a payment link (recurring / subscription)

```bash
stripe payment_links create \
  --line-items[0][price]=price_recurring_XXXX \
  --line-items[0][quantity]=1
```

### List payment links

```bash
stripe payment_links list --limit 20
```

### Retrieve a payment link

```bash
stripe payment_links retrieve plink_XXXX
```

### Update a payment link (deactivate)

```bash
stripe payment_links update plink_XXXX --active=false
```

---

## 3. Customers

### Create a customer

```bash
stripe customers create \
  --email "customer@example.com" \
  --name "Jane Doe" \
  --metadata[plan]="pro"
```

### Search customers

```bash
stripe customers search --query "email:'customer@example.com'"
```

### Retrieve a customer

```bash
stripe customers retrieve cus_XXXX
```

### Update a customer

```bash
stripe customers update cus_XXXX \
  --name "Jane Smith" \
  --metadata[status]="vip"
```

### Delete a customer

```bash
stripe customers delete cus_XXXX
```

### List customers (paginated)

```bash
stripe customers list --limit 20
stripe customers list --limit 20 --starting-after cus_XXXX
```

---

## 4. Subscriptions

### Create a subscription

```bash
stripe subscriptions create \
  --customer cus_XXXX \
  --items[0][price]=price_XXXX
```

### Create a subscription with trial

```bash
stripe subscriptions create \
  --customer cus_XXXX \
  --items[0][price]=price_XXXX \
  --trial-period-days 14
```

### List subscriptions

```bash
stripe subscriptions list --customer cus_XXXX --status active
stripe subscriptions list --limit 20 --starting-after sub_XXXX
```

### Update a subscription (upgrade/downgrade)

```bash
# Get subscription item ID first
stripe subscriptions retrieve sub_XXXX

stripe subscription_items update si_XXXX \
  --price price_NEW_XXXX
```

### Cancel a subscription (at period end)

```bash
stripe subscriptions update sub_XXXX --cancel-at-period-end=true
```

### Cancel immediately

```bash
stripe subscriptions cancel sub_XXXX
```

---

## 5. Invoices

### Create a draft invoice

```bash
stripe invoices create --customer cus_XXXX
```

### Add line items to an invoice

```bash
stripe invoiceitems create \
  --customer cus_XXXX \
  --amount 5000 \
  --currency usd \
  --description "Consulting - April 2026"
```

### Finalize an invoice (locks it for sending)

```bash
stripe invoices finalize_invoice in_XXXX
```

### Send an invoice (emails the customer)

```bash
stripe invoices send_invoice in_XXXX
```

### Void an invoice

```bash
stripe invoices void_invoice in_XXXX
```

### List invoices

```bash
stripe invoices list --customer cus_XXXX --limit 20
stripe invoices list --status open --limit 20
```

---

## 6. Refunds

### Issue a full refund

```bash
stripe refunds create --payment-intent pi_XXXX
```

### Issue a partial refund (amount in cents)

```bash
stripe refunds create \
  --payment-intent pi_XXXX \
  --amount 2500
```

### Refund by charge ID

```bash
stripe refunds create --charge ch_XXXX
```

### List refunds

```bash
stripe refunds list --limit 20
```

---

## 7. Checkout Sessions

Hosted checkout pages — best for one-time or subscription payments with minimal code.

### Create a one-time checkout session

```bash
stripe checkout sessions create \
  --success-url "https://yoursite.com/success" \
  --cancel-url "https://yoursite.com/cancel" \
  --line-items[0][price]=price_XXXX \
  --line-items[0][quantity]=1 \
  --mode=payment
```

### Create a subscription checkout session

```bash
stripe checkout sessions create \
  --success-url "https://yoursite.com/success" \
  --cancel-url "https://yoursite.com/cancel" \
  --line-items[0][price]=price_recurring_XXXX \
  --line-items[0][quantity]=1 \
  --mode=subscription
```

### Retrieve a checkout session

```bash
stripe checkout sessions retrieve cs_XXXX
```

---

## 8. Balance & Payouts

### Check account balance

```bash
stripe balance retrieve
```

### List payouts

```bash
stripe payouts list --limit 10
stripe payouts list --limit 10 --starting-after po_XXXX
```

### Retrieve a payout

```bash
stripe payouts retrieve po_XXXX
```

---

## 9. Webhooks

### Listen locally (test mode — forwards events to your local server)

```bash
stripe listen --forward-to localhost:3000/webhook
```

### Listen and filter specific events

```bash
stripe listen \
  --events payment_intent.succeeded,customer.subscription.created \
  --forward-to localhost:3000/webhook
```

### Forward to a named endpoint

```bash
stripe listen --forward-to https://yoursite.com/webhook
```

### Trigger a test event manually

```bash
stripe trigger payment_intent.succeeded
stripe trigger customer.subscription.created
stripe trigger invoice.payment_failed
```

### List webhook endpoints (registered in dashboard)

```bash
stripe webhook_endpoints list
```

See `references/webhook-patterns.md` for key event types and handler patterns.

---

## 10. Disputes

### List disputes

```bash
stripe disputes list --limit 20
```

### Retrieve a dispute

```bash
stripe disputes retrieve dp_XXXX
```

### Update dispute with evidence

```bash
stripe disputes update dp_XXXX \
  --evidence[customer_email_address]="customer@example.com" \
  --evidence[product_description]="Pro Plan subscription" \
  --evidence[uncategorized_text]="Customer agreed to terms on sign-up."
```

### Close a dispute (accept loss)

```bash
stripe disputes close dp_XXXX
```

---

## Common Flags

| Flag | Purpose |
|------|---------|
| `--api-key sk_test_...` | Override default key (test or live) |
| `--limit N` | Paginate results (max 100) |
| `--starting-after obj_ID` | Cursor-based pagination |
| `--expand[0]=data.payment_intent` | Expand nested objects in response |
| `--format json` | Output raw JSON |

---

## Test Mode Cards

| Card Number | Behavior |
|-------------|----------|
| `4242 4242 4242 4242` | Always succeeds |
| `4000 0000 0000 9995` | Always declines |
| `4000 0025 0000 3155` | Requires 3D Secure |

Use any future expiry date and any 3-digit CVC.

---

## References

- `references/common-workflows.md` — End-to-end workflows (payment links, subscriptions, invoices)
- `references/webhook-patterns.md` — Event types, handler patterns, testing
- `scripts/stripe-health-check.sh` — Verify auth, connectivity, and account info
