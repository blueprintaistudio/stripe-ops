# Common Stripe Workflows

End-to-end playbooks for the most frequent Stripe use cases.

---

## Workflow 1: Payment Link (Instant Shareable Checkout)

**Goal:** Create a shareable URL that accepts one-time payments — no code needed.

### Step 1: Create a product

```bash
stripe products create \
  --name "Website Audit" \
  --description "Full SEO and performance audit"
```

Note the `id` → `prod_XXXX`

### Step 2: Create a price

```bash
stripe prices create \
  --product prod_XXXX \
  --unit-amount 19900 \
  --currency usd
```

Note the `id` → `price_XXXX`

### Step 3: Create the payment link

```bash
stripe payment_links create \
  --line-items[0][price]=price_XXXX \
  --line-items[0][quantity]=1
```

The response includes `url` — share this directly with your customer.

### Step 4: Deactivate when done

```bash
stripe payment_links update plink_XXXX --active=false
```

---

## Workflow 2: Subscription Setup (SaaS / Membership)

**Goal:** Charge a customer monthly on autopilot.

### Step 1: Create a product

```bash
stripe products create --name "Starter Plan"
```

### Step 2: Create a recurring price

```bash
stripe prices create \
  --product prod_XXXX \
  --unit-amount 4900 \
  --currency usd \
  --recurring[interval]=month
```

### Step 3: Create the customer

```bash
stripe customers create \
  --email "user@example.com" \
  --name "Alex Johnson"
```

### Step 4: Collect payment method via Checkout

```bash
stripe checkout sessions create \
  --success-url "https://yourapp.com/welcome" \
  --cancel-url "https://yourapp.com/pricing" \
  --customer cus_XXXX \
  --line-items[0][price]=price_XXXX \
  --line-items[0][quantity]=1 \
  --mode=subscription
```

Share the returned `url` — after the customer completes checkout, the
subscription is active and Stripe handles recurring billing automatically.

### Step 5: Monitor the subscription

```bash
stripe subscriptions list --customer cus_XXXX --status active
```

### Step 6: Upgrade the customer to a higher tier

```bash
# Get the subscription item ID
stripe subscriptions retrieve sub_XXXX
# Look for items.data[0].id → si_XXXX

stripe subscription_items update si_XXXX \
  --price price_HIGHER_TIER_XXXX
```

### Step 7: Cancel at period end

```bash
stripe subscriptions update sub_XXXX --cancel-at-period-end=true
```

---

## Workflow 3: Invoice Flow (Freelance / Agencies)

**Goal:** Create, send, and collect payment for a custom invoice.

### Step 1: Ensure the customer exists

```bash
stripe customers search --query "email:'client@company.com'"
# or create:
stripe customers create \
  --email "client@company.com" \
  --name "Acme Corp"
```

### Step 2: Add line items (invoice items)

Add each service/deliverable as a line item:

```bash
stripe invoiceitems create \
  --customer cus_XXXX \
  --amount 150000 \
  --currency usd \
  --description "Brand Strategy — April 2026"

stripe invoiceitems create \
  --customer cus_XXXX \
  --amount 50000 \
  --currency usd \
  --description "Logo Design Revisions"
```

### Step 3: Create the invoice (collects pending items automatically)

```bash
stripe invoices create \
  --customer cus_XXXX \
  --collection-method=send_invoice \
  --days-until-due 14
```

Note the invoice `id` → `in_XXXX`

### Step 4: Finalize the invoice

```bash
stripe invoices finalize_invoice in_XXXX
```

### Step 5: Send the invoice to the customer

```bash
stripe invoices send_invoice in_XXXX
```

Stripe emails the customer a hosted invoice page with a Pay button.

### Step 6: Check payment status

```bash
stripe invoices retrieve in_XXXX
# Look for status: "paid" or "open"
```

### Step 7: Void if needed (before payment)

```bash
stripe invoices void_invoice in_XXXX
```

---

## Workflow 4: Refund a Payment

**Goal:** Issue a full or partial refund for a completed payment.

### Find the payment

```bash
stripe payment_intents list --customer cus_XXXX --limit 5
# or search by email in the dashboard and grab pi_XXXX
```

### Full refund

```bash
stripe refunds create --payment-intent pi_XXXX
```

### Partial refund (amount in cents)

```bash
stripe refunds create \
  --payment-intent pi_XXXX \
  --amount 5000
# Refunds $50.00
```

---

## Workflow 5: Annual Subscription (Yearly Billing)

```bash
stripe prices create \
  --product prod_XXXX \
  --unit-amount 49900 \
  --currency usd \
  --recurring[interval]=year
```

Then use this price in a Checkout Session or Payment Link as usual.

---

## Workflow 6: Test the Full Payment Flow

Use test cards to verify your integration without real charges:

```bash
# Start local webhook listener
stripe listen --forward-to localhost:3000/webhook

# In another terminal, trigger a payment
stripe trigger payment_intent.succeeded

# Verify the event was received in your app logs
```

Test card for checkout: `4242 4242 4242 4242`, any future date, any CVC.
