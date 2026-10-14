<img src="https://avatars.githubusercontent.com/u/22528478?s=200&v=4" alt="Paubox" width="150px">

# Paubox Gem
This is the official Ruby wrapper for the Paubox API. It supports the Paubox Email API — which allows your application to send secure, HIPAA compliant email via Paubox and track deliveries and opens — and the Paubox Forms API, which allows you to fetch form definitions, submit form responses, and manage forms and their submissions.

It extends the [Ruby Mail Library](https://github.com/mikel/mail) for seamless integration in your existing Ruby application. The API wrapper also allows you to construct and send messages directly without the Ruby Mail Library.

# Table of Contents
* [Installation](#installation)
* [Usage](#usage)
  * [Sending Email](#sending-messages-with-the-ruby-mail-library)
  * [Paubox Forms](#paubox-forms)
* [Contributing](#contributing)
* [License](#license)


<a name="#installation"></a>
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paubox'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install paubox

### Getting Paubox API Credentials
You will need to have a Paubox account. You can [sign up here](https://www.paubox.com/pricing/paubox-email-api).

Once you have an account, follow the instructions on the Rest API dashboard to verify domain ownership and generate API credentials.

### Configuring API Credentials
Include your API credentials in an initializer (e.g. config/initializers/paubox.rb in Rails).

Keep your API credentials out of version control. Store these in environment variables.

```ruby
Paubox.configure do |config|
  config.api_key = ENV['PAUBOX_API_KEY']
end
```

_Note: earlier versions of this gem also required an `api_user`. It is no longer needed — the API key alone authenticates. The `api_user` configuration option is deprecated and ignored._

If you need to send from multiple domains, you can pass credentials in the options hash when you set Ruby Mail's `Mail#delivery_method`, or when using `Paubox::Message`, when you instantiate `Paubox::Client`.

**(optional) Setting credentials when using Ruby Mail:**

```ruby
message = Mail.new do
  ...
  delivery_method(Mail::Paubox, api_key: ENV['PAUBOX_API_KEY'])
end
```

**(optional) Setting credentials when using Paubox::Client:**

```ruby
client = Paubox::Client.new(api_key: ENV['PAUBOX_API_KEY'])
```

<a name="#usage"></a>
## Usage

### Sending Messages with the Ruby Mail Library

Using the Ruby Mail Library? Sending via Paubox is easy. Just build a message as normal and set Mail::Paubox as the delivery method.

```ruby
require 'Paubox'
require 'json'
require 'mail'

message = Mail.new do
  from            'you@yourdomain.com'
  to              'someone@somewhere.com'
  cc              'another@somewhere.com'
  subject         'HIPAA-compliant email made easy'

  text_part do
    body          'This message will be sent securely by Paubox.'
  end

  html_part do
    content_type  'text/html; charset=UTF-8'
    body          '<h1>This message will be sent securely by Paubox.</h1>'
  end

  delivery_method Mail::Paubox
end

message.deliver!
=> {"message"=>"Service OK", "sourceTrackingId"=>"2a3c048485aa4cf6"}

message.source_tracking_id
=> "2a3c048485aa4cf6"
```

### Allowing non-TLS message delivery

If you want to send non-PHI mail that does not need to be HIPAA compliant, you can allow the message delivery to take place even if a TLS connection is unavailable. This means a message will not be converted into a secure portal message when a non-TLS connection is encountered.

```ruby
require 'Paubox'
require 'json'
require 'mail'

message = Mail.new do
  from            'you@yourdomain.com'
  to              'someone@somewhere.com'
  subject         'Sending non-PHI'
  body            'This message delivery will not enforce TLS transmission.'

  delivery_method Mail::Paubox
end

message.allow_non_tls = true
message.deliver!
```

### Forcing Secure Notifications

Paubox Secure Notifications allow an extra layer of security, especially when coupled with an organization's requirement for message recipients to use 2-factor authentication to read messages (this setting is available to org administrators in the Paubox Admin Panel).

Instead of receiving an email with the message contents, the recipient will receive a notification email that they have a new message in Paubox.

```ruby
require 'Paubox'
require 'json'
require 'mail'

message = Mail.new do
  from            'you@yourdomain.com'
  to              'someone@somewhere.com'
  subject         'Sending non-PHI'
  body            'This message delivery will not enforce TLS transmission.'

  delivery_method Mail::Paubox
end

message.force_secure_notification = 'true'
message.deliver!
```

### Adding Attachments

```ruby
require 'Paubox'
require 'json'
require 'mail'

message = Mail.new do
  from            'you@yourdomain.com'
  to              'someone@somewhere.com'
  cc              'another@somewhere.com'
  subject         'HIPAA-compliant email made easy'

  delivery_method Mail::Paubox
end

message.add_file("path_to_your_file")
message.deliver!
```

### Sending Messages using just the Paubox API
You don't need to use Ruby Mail to build and send messages with Paubox.

```ruby
require 'Paubox'
require 'json'

args = { from: 'you@yourdomain.com',
         to: 'someone@domain.com, someone-else@domain.com',
         cc: ['another@domain.com', 'yet-another@domain.com'],
         bcc: 'bcc-recipient@domain.com',
         reply_to: 'reply-to@yourdomain.com',
         subject: 'Testing!',
         text_content: 'Hello World!',
         html_content: '<h1>Hello World!</h1>'         
      }

message = Paubox::Message.new(args)

client = Paubox::Client.new
client.deliver_mail(message)
=> {"message"=>"Service OK", "sourceTrackingId"=>"2a3c048485aa4cf6"}
```
### Manage Dynamic Templates
Can manage(create, update, find and delete) the dynamic templates. by using the following commands and use these to send the Templated Messages.

```ruby
require 'Paubox'
require 'json'

template_name = "Template name"
template_path = "Template File path"

# For create the new dynamic template
Paubox::DynamicTemplates.create(template_name, template_path)
=> { "RestClient::Response"=>"201", "message"=>"Template #{name} created!" }

# For getting the list of all dynamic template of your organization
Paubox::DynamicTemplates.list
=>[{"id"=>1, "name"=>"test", "api_customer_id"=>11},
 {"id"=>3, "name"=>"Test", "api_customer_id"=>11}]


# For update the existing dynamic template
dynamic_template = Paubox::DynamicTemplates.find(template_id)
dynamic_template.update(template_path, template_name)
=> {"RestClient::Response"=>"200", "message"=>"Template #{name} updated!"}

# For delete the existing dynamic template
dynamic_template = Paubox::DynamicTemplates.find(template_id)
dynamic_template.delete
=> {"RestClient::Response"=>"200", "message"=>"Template #{name} deleted!"}


```

### Send Messages using Dynamic Templates
Using above[dynamic templates](https://docs.paubox.com/email-api/dynamic-templates) is similar to sending a regular message. Just create a `Paubox::TemplatedMessage` object and pass a `template` object with the name of the template and variables:

```ruby
require 'Paubox'
require 'json'

args = { from: 'you@yourdomain.com',
         to: 'someone@domain.com, someone-else@domain.com',
         cc: ['another@domain.com', 'yet-another@domain.com'],
         bcc: 'bcc-recipient@domain.com',
         reply_to: 'reply-to@yourdomain.com',
         subject: 'Testing!',
         template: {
          name: 'Test Template',
          values: {
            first_name: 'Timothy',
            last_name: 'Testerson'
          }
        }			
      }

templated_message = Paubox::TemplatedMessage.new(args)

client = Paubox::Client.new
client.deliver_mail(templated_message)
=> {"sourceTrackingId"=>"166904b5-dce7-4de1-92e8-3d505c165ff5", "data"=>"Service OK"}
```

_Note that there is no `content` when using templated messages._


### Checking Email Dispositions
```ruby
require 'Paubox'
require 'json'

client = Paubox::Client.new
email_disposition = client.email_disposition('2a3c048485aa4cf6')

# Get array of email_dispositions. One email_disposition is generated for each recipient.
message_deliveries = email_disposition.message_deliveries
=> [<struct Paubox::EmailDisposition::MessageDelivery recipient="test@domain.com", status=#<struct Paubox::EmailDisposition::MessageDeliveryStatus delivery_status="delivered", delivery_time=Mon, 30 Apr 2018 12:54:19 -0700, opened_status="opened", opened_time=Mon, 30 Apr 2018 12:55:19 -0700>>]

# Inspect a message delivery
delivery = message_deliveries.first

delivery.recipient
=> "test@domain.com"

# Inspect the message delivery status
status = delivery.status

status.delivery_status
=> "delivered"

status.delivery_time
=> Mon, 30 Apr 2018 12:54:19 -0700

# opened_status is only available for single-recipient messages
status.opened_status
=> "opened"

# opened_time is only available for single-recipient messages
status.opened_time
=> Mon, 30 Apr 2018 12:55:19 -0700
```

<a name="#paubox-forms"></a>
## Paubox Forms

The Paubox Forms API has two kinds of endpoints. **Public endpoints** (fetching a form definition, submitting a form) require no authentication and are intended for form embed use cases. **Authenticated endpoints** (managing forms and their submissions) require a Paubox API key scoped to `forms`.

### Public Endpoints (No Authentication)

These endpoints send no auth header, so `Paubox::FormsClient` can be constructed without any credentials.

#### Getting Form Metadata

```ruby
require 'Paubox'

client = Paubox::FormsClient.new
form   = client.get_form('550e8400-e29b-41d4-a716-446655440000')

form.title            # => "Patient Intake Form"
form.description      # => "Please complete before your appointment."
form.active?          # => true
form.signable?        # => false
form.submission_count # => 42
form.form_html        # => "<form>...</form>"
form.form_json        # => { ... }
```

#### Submitting a Form

```ruby
require 'Paubox'

client = Paubox::FormsClient.new

client.submit_form('550e8400-e29b-41d4-a716-446655440000',
  form_data: {
    first_name: 'Jane',
    last_name:  'Smith',
    email:      'jane@example.com'
  })
```

#### Submitting a Form with Attachments

File attachments must be base64-encoded. The maximum request size is 250 MB.

```ruby
require 'Paubox'
require 'base64'

client = Paubox::FormsClient.new

client.submit_form('550e8400-e29b-41d4-a716-446655440000',
  form_data: {
    first_name: 'Jane',
    signature:  '{signature_field}'
  },
  attachments: [
    {
      name:    'consent.pdf',
      content: Base64.strict_encode64(File.binread('consent.pdf'))
    }
  ])
```

### Authenticated Endpoints (Scoped API Key)

Form management endpoints require a Paubox API key scoped to `forms`. This is a different key from the Email API key (`Paubox.configuration.api_key`), which is never used for Forms endpoints. Pass the forms key when you instantiate the client, or configure it via `Paubox.configure` (the client falls back to `Paubox.configuration.forms_api_key`). The key is sent as an `Authorization: Bearer` header on every management request.

```ruby
require 'Paubox'

client = Paubox::FormsClient.new(api_key: ENV['PAUBOX_FORMS_API_KEY'])

# or globally:
Paubox.configure { |config| config.forms_api_key = ENV['PAUBOX_FORMS_API_KEY'] }
client = Paubox::FormsClient.new
```

Calling a management endpoint without an API key raises `ArgumentError`.

#### Listing Forms

Supports filtering, ordering, and pagination. `customer_id` is required and must match the API key's customer — the client raises `ArgumentError` without it. Optional params: `form_id`, `search`, `order` (`'asc'`/`'desc'`), `order_by` (`'title'`, `'updated_at'`, `'submission_count'`, `'created_at'`), `archived`, `active`, `page`, and `items` (capped at 100 by the server).

```ruby
result = client.list_forms(customer_id: 123, search: 'intake',
                           order_by: 'updated_at', order: 'desc',
                           page: 1, items: 25)

result[:forms].first.title # => "Patient Intake Form"
result[:page_info]         # => {"count"=>42, "pages"=>2, "page"=>1, "items"=>25}
```

#### Creating a Form

Required attributes: `title`, `form_json`, `customer_id`, and `version`. Optional attributes include `description`, `form_html`, `form_css`, `recipient`, `signable`, `signature_confirmation_label`, `subscription_list_id`, `type`, and `active`.

```ruby
client.create_form(title: 'Patient Intake Form',
                   form_json: { fields: [{ name: 'first_name' }] },
                   customer_id: 123,
                   version: 1,
                   recipient: 'intake@yourdomain.com')
=> {"id"=>"550e8400-e29b-41d4-a716-446655440000"}
```

#### Finding a Form

Returns a `Paubox::Form`. Unlike the public `get_form`, `find_form` can fetch inactive and archived forms.

```ruby
form = client.find_form('550e8400-e29b-41d4-a716-446655440000')

form.title     # => "Patient Intake Form"
form.archived? # => false
form.recipient # => "intake@yourdomain.com"
```

#### Updating a Form

Updates are partial: fields you omit are left unchanged. Updatable fields: `title`, `description`, `form_json`, `vanity_url`, `recipient`, `active`, and `subscription_list_id`.

```ruby
client.update_form('550e8400-e29b-41d4-a716-446655440000',
                   title: 'Patient Intake Form (v2)',
                   active: false)
=> {"detail"=>"Form updated successfully", "form_id"=>"550e8400-e29b-41d4-a716-446655440000"}
```

#### Archiving and Unarchiving a Form

```ruby
client.archive_form('550e8400-e29b-41d4-a716-446655440000')
=> {"detail"=>"Form archived."}

client.unarchive_form('550e8400-e29b-41d4-a716-446655440000')
=> {"detail"=>"Form unarchived."}
```

#### Copying a Form

Copies an existing form under a new title and returns the new form as a `Paubox::Form`.

```ruby
form = client.copy_form('550e8400-e29b-41d4-a716-446655440000',
                        title: 'Patient Intake Form (Copy)')

form.id    # => "7c9e6679-7425-40de-944b-e07fc1f90ae7"
form.title # => "Patient Intake Form (Copy)"
```

#### Form Stats

Returns aggregate counts. `customer_id` is optional and defaults server-side to the API key's customer.

```ruby
client.form_stats
=> {"active_form_count"=>12, "total_submission_count"=>340, "submissions_last_7_days"=>18}

client.form_stats(customer_id: 123)
```

#### Listing Submissions

Returns `Paubox::FormSubmission` objects plus pagination info. Available params: `submission_id`, `order_by` (`'submitter_email'`, `'created_at'`), `order`, `page`, and `items` (capped at 100 by the server).

```ruby
result = client.list_submissions('550e8400-e29b-41d4-a716-446655440000',
                                 order_by: 'created_at', order: 'desc')

result[:total] # => 42
result[:page]  # => 1
result[:items] # => 25

submission = result[:submissions].first
submission.submitter_email # => "jane@example.com"
submission.form_data       # => {"first_name"=>"Jane", "last_name"=>"Smith"}
submission.created_at      # => "2026-08-01T12:34:56Z"
```

#### Downloading Submissions as CSV

Returns the raw CSV as a `String`. Pass `submission_id:` to download a single submission.

```ruby
# All submissions for a form
csv = client.submissions_csv('550e8400-e29b-41d4-a716-446655440000')
File.write('submissions.csv', csv)

# A single submission
csv = client.submissions_csv('550e8400-e29b-41d4-a716-446655440000',
                             submission_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7')
```

#### Downloading a Submission as PDF

Returns the raw PDF bytes as a `String`.

```ruby
pdf = client.submission_pdf('550e8400-e29b-41d4-a716-446655440000',
                            '7c9e6679-7425-40de-944b-e07fc1f90ae7')
File.binwrite('submission.pdf', pdf)
```

<a name="#webhooks"></a>
## Webhooks

A webhook endpoint is a URL you own that Paubox notifies when something happens.
`Paubox::WebhooksClient` manages those subscriptions: which URL to notify, and for which events.

Every method needs an API key scoped for the events you want, sent as an `Authorization: Bearer`
header — not the Email API's `Token token=`. Pass it to the constructor or configure it globally:

```ruby
require 'Paubox'

client = Paubox::WebhooksClient.new(api_key: ENV['PAUBOX_WEBHOOKS_API_KEY'])

# or globally:
Paubox.configure { |config| config.webhooks_api_key = ENV['PAUBOX_WEBHOOKS_API_KEY'] }
client = Paubox::WebhooksClient.new
```

Which events a key may subscribe to follows from its scopes. The SDK does not inspect them — the
service refuses an event the key isn't scoped for with 403, and an unrecognised event with 422.

**Available events**

| Event | Fires when |
| --- | --- |
| `forms.submission.created` | A form submission is received |
| `api_mail_log_delivered` | An Email API message is delivered |
| `api_mail_log_opened` | A delivered message is opened |
| `api_mail_log_temporary_failure` | Delivery fails temporarily |
| `api_mail_log_permanent_failure` | Delivery fails permanently |
| `email.inbound.received` | Inbound mail is received |

The four Email API events keep their legacy `api_mail_log_` names, so a receiver written
against the old Email API webhooks keeps working unchanged. Note these are the names on
the wire: `delivered` or `failed` on their own are rejected as unknown.

The SDK does not check these names. The catalog lives in the service, so an event added
later works here without upgrading the SDK.

### Creating a webhook endpoint

```ruby
endpoint = client.create_webhook_endpoint(
  target_url: 'https://example.com/paubox-webhook',
  events: ['forms.submission.created']
)

endpoint['id']             # UUID
endpoint['signing_secret'] # whsec_... — store this now
```

`signing_secret` is returned **once**, here. It is absent from `get_webhook_endpoint` and
`list_webhook_endpoints`, and there is no way to read it back — recovering from a lost secret
means deleting the endpoint and creating a new one. Use it to verify that deliveries really came
from Paubox.

### Listing webhook endpoints

```ruby
result = client.list_webhook_endpoints

result['data'].each do |endpoint|
  puts [endpoint['id'], endpoint['target_url'], endpoint['status']].join(' ')
end

result['page_info']['count'] # total matching, not the length of this page

# Paginated
client.list_webhook_endpoints(page: 2, items: 25)
```

### Getting, updating and deleting

```ruby
endpoint = client.get_webhook_endpoint('2ec66c21-bf48-48eb-8d28-f80b2d6b77c7')

# Only the keyword arguments you pass are sent
endpoint = client.update_webhook_endpoint(id, status: 'disabled')

client.delete_webhook_endpoint(id) # => true
```

Pausing deliveries without losing the subscription is what `disabled` is for; pass `active` to
resume. Passing `events:` replaces the list rather than adding to it. Deleting answers `204 No
Content`, stops every event on that endpoint, and takes the signing secret with it.

### Error handling

A non-2xx response raises `Paubox::WebhooksClient::Error`, carrying the service's own message
rather than a bare status:

```ruby
begin
  client.create_webhook_endpoint(target_url: url, events: ['forms.submission.created'])
rescue Paubox::WebhooksClient::Error => e
  e.status_code   # 422
  e.message       # "target_url: an endpoint already exists for this URL"
  e.response_body # raw response
  e.url
end
```

The error deliberately carries only those three fields, so an error reporter capturing locals from
the raising frame never picks up the `Authorization` header or the API key.

Two cases worth handling explicitly: subscribing a `target_url` that already has an endpoint comes
back as 422, and an id that doesn't belong to your account is a 404 rather than a 403. An id that
isn't a UUID raises `ArgumentError` locally, before any request is made, as does calling any
method without an API key.

<a name="#contributing"></a>
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paubox/paubox-ruby.


<a name="#license"></a>
## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Copyright
Copyright &copy; 2022, Paubox, Inc.

## 💬 Community & support

Questions, ideas, or want to share what you built? Join the **[Paubox Community](https://github.com/Paubox/community/discussions)** — the single home for discussions across every Paubox SDK and API.

🔐 Found a security issue? Email **devops@paubox.com** — please don't post it publicly.
