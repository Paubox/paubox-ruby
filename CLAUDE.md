# Paubox Ruby Gem — Developer Context

## Purpose

This is the official Ruby gem for the Paubox platform. It provides:
- **Email API**: send HIPAA-compliant email, manage dynamic templates, check delivery status
- **Forms API**: fetch form definitions, submit form responses, and manage forms and submissions

## Directory Structure

```
lib/
  paubox.rb                  # Entry point: requires all lib files, holds Configuration
  paubox_ruby.rb             # Alias for paubox.rb
  paubox/
    version.rb               # Gem version constant
    client.rb                # Email API client (authenticated, api.paubox.com)
    forms_client.rb          # Forms API client (api.paubox.com/v1/forms; Bearer auth on management endpoints)
    message.rb               # Builds send-message API payload from a hash
    templated_message.rb     # Extends Message for template-based sends
    mail_to_message.rb       # Adapts Ruby Mail::Message to API payload
    dynamic_templates.rb     # CRUD for dynamic email templates
    email_disposition.rb     # Parses delivery/open status responses
    form.rb                  # Parses form metadata responses
    form_submission.rb       # Parses form submission responses
    format_helper.rb         # Shared utilities: base64, key mapping, normalization
  mail/
    paubox.rb                # Plugs Paubox into Ruby Mail as a delivery method

spec/
  spec_helper.rb             # RSpec + WebMock setup
  paubox/                    # Unit specs per class
  mail/                      # Specs for Ruby Mail integration
  helpers/                   # Shared fixtures (MessageHelper, FormHelper, etc.)
```

## Key Classes

| Class | Responsibility |
|---|---|
| `Paubox::Client` | Authenticated HTTP client for the Email API. Token auth via `Authorization: Token token=<key>`. Base URL: `https://api.paubox.com/v1`. |
| `Paubox::FormsClient` | HTTP client for the Forms API. Base URL: `https://api.paubox.com/v1/forms`. Public endpoints (`get_form`, `submit_form`) send no auth headers; management endpoints (list/create/find/update/archive/copy forms, stats, submissions, CSV/PDF export) require a "forms"-scoped API key sent as `Authorization: Bearer <api_key>`. |
| `Paubox::Message` | Builds the JSON payload for `/messages`. Accepts `from`, `to`, `cc`, `bcc`, `subject`, `text_content`, `html_content`, `attachments`. |
| `Paubox::TemplatedMessage` | Extends `Message`; overrides `send_message_payload` to include `template_name` / `template_values`. |
| `Paubox::MailToMessage` | Converts a `Mail::Message` object into a Paubox API payload. |
| `Paubox::DynamicTemplates` | Manages template CRUD via class methods (`create`, `list`, `find`) and instance methods (`update`, `delete`). |
| `Paubox::EmailDisposition` | Parses the `/message_receipt` response into `MessageDelivery` and `MessageDeliveryStatus` structs. |
| `Paubox::Form` | Parses form responses (`/public/form_data/<id>`, `/api/forms` endpoints). Exposes predicate methods: `active?`, `deleted?`, `archived?`, `signable?`. |
| `Paubox::FormSubmission` | Parses a form submission from `/api/forms/<form_id>/submissions`. Exposes `id`, `form_id`, `form_data` (JSON string parsed to a Hash), `submitter_email`, `recipients`, attachment fields, `created_at`. |
| `Paubox::FormatHelper` | Mixed into message builders; handles base64 encoding, snake_case→camelCase key mapping, email list normalization. |
| `Mail::Paubox` | Delivery method for the Ruby Mail library. Delegates to `Paubox::Client`. |

## Adding a New Feature

### New API endpoint on the Email API
1. Add a method to `Paubox::Client` that calls `send_request` or `RestClient` directly.
2. If the response needs a structured model, create `lib/paubox/<model>.rb` following `EmailDisposition` as a pattern.
3. Require the new file in `lib/paubox.rb`.
4. Add specs in `spec/paubox/<feature>_spec.rb` using WebMock to stub HTTP.

### New API endpoint on the Forms API
1. Add a method to `Paubox::FormsClient`.
2. If needed, add a response model following `Paubox::Form`.
3. Require in `lib/paubox.rb`.
4. Add specs in `spec/paubox/forms_client_spec.rb` or a new file.

## Testing

**Framework:** RSpec 3 + WebMock

```bash
bundle exec rspec                    # run all specs
bundle exec rspec spec/paubox/form_spec.rb   # run a single file
```

WebMock stubs outbound HTTP. All specs must stub any HTTP calls they trigger — no real network requests are made.

Fixtures live in `spec/helpers/` as includable modules (e.g. `Helpers::FormHelper`, `Helpers::MessageHelper`). Include them per spec file with `RSpec.configure { |c| c.include Helpers::XHelper }`.

## Authentication

- **Email API**: `Authorization: Token token=<api_key>` header on every request. The API key alone authenticates — no username/user segment is needed. Configured via `Paubox.configure` or `Paubox::Client.new(api_key:)`. `Configuration` keeps a deprecated `api_user` accessor for backward compatibility; it is ignored.
- **Forms API**: Public endpoints (`get_form`, `submit_form`) need no auth — `Paubox::FormsClient` sends no auth headers for them. Management endpoints require an API key with the "forms" scope (validated server-side, not by the gem), sent as `Authorization: Bearer <api_key>`. This is a separate key from the Email API key: configure it via `Paubox.configure { |c| c.forms_api_key = ... }` or `Paubox::FormsClient.new(api_key:)` — the client never falls back to `Paubox.configuration.api_key`. Calling a management endpoint without a key raises `ArgumentError`. Note: `list_forms` requires `customer_id` (must match the API key's customer, enforced server-side; the gem raises `ArgumentError` if it is missing).

## Dependencies

- `rest-client` (~> 2.0) — HTTP client
- `mail` (>= 2.5) — Ruby Mail integration

## Releases

Releases are automated with [release-please](https://github.com/googleapis/release-please). Merging to `master` refreshes a standing release PR; merging *that* PR bumps `lib/paubox/version.rb`, writes `CHANGELOG.md`, creates a bare `vX.Y.Z` tag and a GitHub release, and then **pushes the gem to RubyGems**.

Do **not** hand-edit `VERSION` or add a `CHANGELOG.md` entry — release-please owns both.

The next version comes from PR titles, so the title is the only thing that matters: `feat:` gives a minor bump, `fix:` a patch, and a `!` suffix or a `BREAKING CHANGE:` footer gives a major. `.github/workflows/pr-title.yml` rejects titles release-please cannot parse.

To force a specific version, land an empty commit carrying a `Release-As` footer. Put the release notes in that commit's body — a bare `chore: release X` produces an empty changelog entry, because the commits it would otherwise draw from get dropped if they are not conventional:

```bash
git commit --allow-empty -m "chore: release 1.0.0" -m "Release-As: 1.0.0"
```

### Publishing

Publishing uses RubyGems **trusted publishing** (OIDC) — there is no API key stored anywhere. RubyGems pins the trust to the repository and the workflow filename, so **renaming `release-please.yml` breaks publishing** until the trusted publisher entry for the `paubox` gem is updated to match.

If a push fails, re-run the failed `publish` job from the Actions tab. Note that a re-run uses the workflow file from the original commit, so it only helps when the fix is on the RubyGems side; a fix to the workflow itself needs a new release.

Version numbers on RubyGems are effectively permanent — a yank is only possible within 72 hours and never frees the number for reuse.

### Relationship to `paubox_rails`

`paubox_rails` depends on this gem. Its gemspec constraint has to allow whatever major version is current here, so a major bump in `paubox` requires a matching `paubox_rails` release that widens the constraint. Release `paubox` first.
