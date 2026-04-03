# Webhook Patterns

Reference for Stripe webhook event types, local testing, endpoint registration,
and common handler patterns.

---

## Quick Setup

### Listen locally (test mode)

```bash
stripe listen --forward-to localhost:3000/webhook
```

This proxies live test-mode events to your local server. The CLI prints a
**webhook signing secret** (`whsec_...`) — use it to verify events in your code.

### Filter to specific events

```bash
stripe listen \
  --events payment_intent.succeeded,invoice.payment_failed \
  --forward-to localhost:3000/webhook
```

### Forward to a staging URL

```bash
stripe listen --forward-to https://staging.yourapp.com/webhook
```

---

## Manually Trigger Test Events

```bash
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.payment_failed
stripe trigger customer.subscription.created
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted
stripe trigger invoice.created
stripe trigger invoice.finalized
stripe trigger invoice.paid
stripe trigger invoice.payment_failed
stripe trigger customer.created
stripe trigger charge.dispute.created
stripe trigger checkout.session.completed
```

---

## Key Event Types by Category

### Payments

| Event | When it fires |
|-------|--------------|
| `payment_intent.created` | PI is created |
| `payment_intent.succeeded` | Payment collected successfully |
| `payment_intent.payment_failed` | Payment attempt failed |
| `charge.succeeded` | Charge completes |
| `charge.failed` | Charge declined |
| `charge.refunded` | Refund issued |

### Subscriptions

| Event | When it fires |
|-------|--------------|
| `customer.subscription.created` | New subscription starts |
| `customer.subscription.updated` | Plan change, trial end, etc. |
| `customer.subscription.deleted` | Subscription cancelled |
| `customer.subscription.trial_will_end` | 3 days before trial ends |

### Invoices

| Event | When it fires |
|-------|--------------|
| `invoice.created` | Draft invoice created |
| `invoice.finalized` | Invoice locked (can now be sent) |
| `invoice.sent` | Invoice emailed to customer |
| `invoice.paid` | Invoice marked paid |
| `invoice.payment_failed` | Payment attempt on invoice failed |
| `invoice.voided` | Invoice voided |

### Checkout

| Event | When it fires |
|-------|--------------|
| `checkout.session.completed` | Customer completed checkout |
| `checkout.session.expired` | Session timed out without completion |

### Customers

| Event | When it fires |
|-------|--------------|
| `customer.created` | New customer object created |
| `customer.updated` | Customer fields changed |
| `customer.deleted` | Customer deleted |

### Disputes

| Event | When it fires |
|-------|--------------|
| `charge.dispute.created` | Customer files a chargeback |
| `charge.dispute.updated` | Dispute evidence updated |
| `charge.dispute.closed` | Dispute resolved (won/lost) |

---

## Webhook Endpoint Registration (Production)

Register a permanent endpoint in your Stripe dashboard or via CLI:

```bash
stripe webhook_endpoints create \
  --url "https://yourapp.com/webhook" \
  --enabled-events payment_intent.succeeded,invoice.paid,customer.subscription.deleted
```

List registered endpoints:

```bash
stripe webhook_endpoints list
```

Retrieve a specific endpoint:

```bash
stripe webhook_endpoints retrieve we_XXXX
```

Update events on an endpoint:

```bash
stripe webhook_endpoints update we_XXXX \
  --enabled-events payment_intent.succeeded,invoice.payment_failed
```

Delete an endpoint:

```bash
stripe webhook_endpoints delete we_XXXX
```

---

## Handler Pattern (Node.js / Express)

```javascript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET; // whsec_...

app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  switch (event.type) {
    case 'payment_intent.succeeded':
      const pi = event.data.object;
      // Fulfill order, send confirmation email
      break;

    case 'invoice.payment_failed':
      const invoice = event.data.object;
      // Notify customer, retry logic
      break;

    case 'customer.subscription.deleted':
      const sub = event.data.object;
      // Revoke access, send win-back email
      break;
  }

  res.json({ received: true });
});
```

---

## Handler Pattern (Python / Flask)

```python
import stripe
from flask import Flask, request, jsonify

app = Flask(__name__)
stripe.api_key = os.environ['STRIPE_SECRET_KEY']
endpoint_secret = os.environ['STRIPE_WEBHOOK_SECRET']

@app.route('/webhook', methods=['POST'])
def webhook():
    payload = request.data
    sig_header = request.headers.get('Stripe-Signature')

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except ValueError:
        return 'Invalid payload', 400
    except stripe.error.SignatureVerificationError:
        return 'Invalid signature', 400

    if event['type'] == 'payment_intent.succeeded':
        pi = event['data']['object']
        # Handle success

    elif event['type'] == 'invoice.payment_failed':
        invoice = event['data']['object']
        # Handle failure

    return jsonify(success=True)
```

---

## Critical Webhook Rules

1. **Always verify the signature** using `whsec_...` — never trust raw POST bodies
2. **Return 200 fast** — do heavy processing asynchronously (queue jobs)
3. **Handle duplicates** — Stripe may deliver the same event more than once; make handlers idempotent
4. **Use the object in the event payload** — don't re-fetch unless you need fresh data
5. **Test every event type** you handle using `stripe trigger` before going live

---

## Debugging Webhooks

```bash
# See recent events in the dashboard-equivalent CLI output
stripe events list --limit 10

# Retrieve a specific event
stripe events retrieve evt_XXXX

# Replay an event to your local listener
stripe events resend evt_XXXX
```
