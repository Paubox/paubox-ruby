# Paubox Ruby Gem — API Reference

## Email API

### Authentication

All Email API requests use token-based authentication. The API key alone authenticates — no username is required. Configure the key once globally or pass it per client instance.

**Global configuration:**
```ruby
Paubox.configure do |config|
  config.api_key = ENV['PAUBOX_API_KEY']
end
```

**Per-instance:**
```ruby
client = Paubox::Client.new(api_key: ENV['PAUBOX_API_KEY'])
```

_The `api_user` configuration option is deprecated and ignored._

**Authorization header sent on every request:**
```
Authorization: Token token=<api_key>
```

### Base URL

```
https://api.paubox.com/v1/email
```

All Email API paths below are relative to this base.

---

### Send Message

**POST** `/messages`

Sends a HIPAA-compliant email.

**Request body:**
```json
{
  "data": {
    "message": {
      "recipients": ["recipient@example.com"],
      "cc": [],
      "bcc": [],
      "allowNonTLS": false,
      "headers": {
        "from": "sender@yourdomain.com",
        "reply-to": "reply@yourdomain.com",
        "subject": "Hello"
      },
      "content": {
        "text/plain": "Plain text body",
        "text/html": "<h1>HTML body</h1>"
      },
      "attachments": [
        {
          "fileName": "file.pdf",
          "contentType": "application/pdf",
          "content": "<base64-encoded content>"
        }
      ]
    }
  }
}
```

**Optional fields:**
- `forceSecureNotification` (`"true"` / `"false"`) — forces portal delivery
- `allowNonTLS` (`true` / `false`) — allows delivery without TLS

**Response (200):**
```json
{ "message": "Service OK", "sourceTrackingId": "2a3c048485aa4cf6" }
```

---

### Send Templated Message

**POST** `/templated_messages`

Sends a message using a dynamic template.

**Request body:**
```json
{
  "data": {
    "recipients": ["recipient@example.com"],
    "headers": { "from": "sender@yourdomain.com", "subject": "Hello" },
    "template_name": "My Template",
    "template_values": { "first_name": "Jane", "last_name": "Smith" }
  }
}
```

**Response (200):**
```json
{ "sourceTrackingId": "166904b5-dce7-4de1-92e8-3d505c165ff5", "data": "Service OK" }
```

---

### Get Email Disposition

**GET** `/message_receipt?sourceTrackingId=<id>`

Returns delivery and open status for a sent message.

**Response (200):**
```json
{
  "sourceTrackingId": "2a3c048485aa4cf6",
  "data": {
    "message": {
      "id": "...",
      "message_deliveries": [
        {
          "recipient": "recipient@example.com",
          "status": {
            "deliveryStatus": "delivered",
            "deliveryTime": "2024-01-15T12:54:19-07:00",
            "openedStatus": "opened",
            "openedTime": "2024-01-15T12:55:19-07:00"
          }
        }
      ]
    }
  }
}
```

---

### Dynamic Templates

All paths are relative to the Email API base URL.

| Operation      | Method  | Path                          |
|----------------|---------|-------------------------------|
| List templates | GET     | `/dynamic_templates`          |
| Get template   | GET     | `/dynamic_templates/<id>`     |
| Create         | POST    | `/dynamic_templates`          |
| Update         | PATCH   | `/dynamic_templates/<id>`     |
| Delete         | DELETE  | `/dynamic_templates/<id>`     |

**Create / Update request body** (`multipart/form-data`):
- `data[name]` — template name
- `data[body]` — template file

---

### API Status

**GET** `/status`

Returns service health. No authentication required in practice.

**Response (200):**
```json
{ "message": "Service OK" }
```

---

## Forms API

### Authentication

**None required.** Forms API endpoints are public and designed for form embed use cases. No API key or authorization header is sent.

### Base URL

```
https://api.paubox.com/v1/forms
```

---

### Get Form Metadata

**GET** `/public/form_data/<form_id>`

Returns the full form definition for a given UUID. Used to render a form to a respondent.

**Path parameter:**
- `form_id` (UUID, required) — the form to retrieve

**Response (200):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Patient Intake Form",
  "description": "Please complete before your appointment.",
  "form_json": {},
  "form_html": "<form>...</form>",
  "form_css": "form { font-family: sans-serif; }",
  "vanity_url": null,
  "version": 1,
  "active": true,
  "customer_id": 123,
  "signable": false,
  "signature_confirmation_label": null,
  "submission_count": 42,
  "type": null,
  "deleted": false,
  "archived": false,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-06-01T08:00:00Z"
}
```

**Errors:**
- `404` — form not found

**Ruby usage:**
```ruby
client = Paubox::FormsClient.new
form   = client.get_form('550e8400-e29b-41d4-a716-446655440000')

form.title            # => "Patient Intake Form"
form.active?          # => true
form.signable?        # => false
form.submission_count # => 42
```

---

### Submit Form Response

**POST** `/api/forms/<form_id>/submissions`

Submits a respondent's answers for a form. On success, the service stores the submission, increments the submission count, emails configured recipients, and returns 201 with no body. Maximum request size is **250 MB**.

**Path parameter:**
- `form_id` (UUID, required) — the form being submitted

**Request body:**
```json
{
  "form_data": {
    "first_name": "Jane",
    "last_name": "Smith",
    "email": "jane@example.com"
  },
  "attachments": [
    {
      "name": "consent.pdf",
      "content": "<base64-encoded file content>"
    }
  ]
}
```

- `form_data` (object, required) — key-value pairs matching the form's field schema
- `attachments` (array, optional) — file attachments; each item requires `name` (filename) and `content` (base64-encoded)

**Response:**
- `201` — submission accepted (no body)
- `400` — missing required `form_data` field
- `404` — form not found

**Ruby usage:**
```ruby
client = Paubox::FormsClient.new

# Text fields only
client.submit_form('550e8400-e29b-41d4-a716-446655440000',
  form_data: { first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com' })

# With file attachments
client.submit_form('550e8400-e29b-41d4-a716-446655440000',
  form_data: { first_name: 'Jane', signature: '{signature_field}' },
  attachments: [
    { name: 'consent.pdf', content: Base64.strict_encode64(File.binread('consent.pdf')) }
  ])
```

---

## Webhooks API

A webhook endpoint is a URL you own that Paubox notifies when something happens. These endpoints
manage those subscriptions.

### Authentication

An API key scoped for the events you want, sent as a Bearer header:

```
Authorization: Bearer <SCOPED_API_KEY>
```

Not the Email API's `Token token=`. Which events a key may subscribe to follows from its scopes;
the SDK does not inspect them, so an event the key is not scoped for returns 403 and an
unrecognised one 422.

### Base URL

```
https://api.paubox.com/v1/webhooks
```

Every request carries the `/endpoints` resource. The bare base is unrouted on the public gateway
by design: the rule is scoped to `/endpoints` so the producers' event-ingest route stays private.

---

### List Webhook Endpoints

**GET** `/endpoints`

Returns the endpoints this key can act on. Endpoints carrying an event the key is not scoped for
are filtered out by the service.

**Query parameters:**
- `page` (integer, optional) — 1-based page number
- `items` (integer, optional) — page size

**Response (200):**
```json
{
  "data": [
    {
      "id": "2ec66c21-bf48-48eb-8d28-f80b2d6b77c7",
      "target_url": "https://example.com/paubox-webhook",
      "status": "active",
      "events": ["forms.submission.created"],
      "created_at": "2026-10-09T01:43:41.639968+00:00",
      "updated_at": "2026-10-09T01:43:41.639968+00:00"
    }
  ],
  "page_info": { "count": 1, "items": 50 }
}
```

`page_info.count` is the total number of matching endpoints, not the length of `data`.

**Ruby usage:**
```ruby
client = Paubox::WebhooksClient.new(api_key: ENV['PAUBOX_WEBHOOKS_API_KEY'])

result = client.list_webhook_endpoints
result = client.list_webhook_endpoints(page: 2, items: 25)
```

Returns the full document — `data` plus `page_info` — since a caller paginating needs both.

---

### Create Webhook Endpoint

**POST** `/endpoints`

**Request body:**
- `target_url` (string, required) — an https URL resolving to a publicly routable address
- `events` (array of strings, required, non-empty)

**Response (201):**
```json
{
  "data": {
    "id": "2ec66c21-bf48-48eb-8d28-f80b2d6b77c7",
    "target_url": "https://example.com/paubox-webhook",
    "status": "active",
    "events": ["forms.submission.created"],
    "created_at": "2026-10-09T01:43:41.639968+00:00",
    "updated_at": "2026-10-09T01:43:41.639968+00:00",
    "signing_secret": "whsec_..."
  },
  "message": "Store this signing_secret now — it is not shown again."
}
```

`signing_secret` is returned only here. It is absent from get and list, and cannot be read back:
recovering from a lost secret means replacing the endpoint.

**Errors:**
- `422` — missing or malformed `target_url`, an empty `events`, an unrecognised event, or a
  `target_url` that already has an endpoint
- `403` — an event this key is not scoped for

**Ruby usage:**
```ruby
endpoint = client.create_webhook_endpoint(
  target_url: 'https://example.com/paubox-webhook',
  events: ['forms.submission.created']
)
endpoint['signing_secret']
```

Returns the endpoint itself, unwrapped from the `data` envelope.

---

### Get Webhook Endpoint

**GET** `/endpoints/<id>`

**Path parameter:**
- `id` (UUID, required)

**Response (200):** the endpoint, wrapped in `data`. The signing secret is not included.

**Errors:**
- `404` — no such endpoint, or it belongs to another account

**Ruby usage:**
```ruby
endpoint = client.get_webhook_endpoint('2ec66c21-bf48-48eb-8d28-f80b2d6b77c7')
```

An id that is not UUID-shaped raises `ArgumentError` before any request is sent.

---

### Update Webhook Endpoint

**PATCH** `/endpoints/<id>`

A partial update: only the fields sent are changed.

**Request body (all optional, at least one required):**
- `target_url` (string)
- `status` (string) — `"active"` or `"disabled"`
- `events` (array of strings) — replaces the list rather than adding to it

**Response (200):** the updated endpoint, wrapped in `data`.

**Ruby usage:**
```ruby
client.update_webhook_endpoint(id, status: 'disabled')
client.update_webhook_endpoint(id, target_url: 'https://example.com/new-hook')
```

`disabled` pauses deliveries without losing the subscription; `active` resumes them.

---

### Delete Webhook Endpoint

**DELETE** `/endpoints/<id>`

**Response:**
- `204` — deleted, no body
- `404` — no such endpoint, or it belongs to another account

Deleting stops every event on that endpoint and discards its signing secret.

**Ruby usage:**
```ruby
client.delete_webhook_endpoint(id) # => true
```

---

### Webhook Errors

Every non-2xx response raises `Paubox::WebhooksClient::Error`:

```ruby
begin
  client.get_webhook_endpoint(id)
rescue Paubox::WebhooksClient::Error => e
  e.status_code   # Integer
  e.message       # the service's own message, e.g. "webhook endpoint not found"
  e.url
  e.response_body # raw response
end
```

The error carries only those fields, so an error reporter capturing locals from the raising frame
never sees the `Authorization` header or the API key.
