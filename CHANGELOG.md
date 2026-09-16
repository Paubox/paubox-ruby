# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0](https://github.com/Paubox/paubox-ruby/compare/v1.1.0...v1.2.0) (2026-09-16)


### Features

* add receiving (inbound email) endpoints ([#29](https://github.com/Paubox/paubox-ruby/issues/29)) ([aeda949](https://github.com/Paubox/paubox-ruby/commit/aeda9497215ce6d701af7eb37ec9ac895910e1b2))

## [1.1.0](https://github.com/Paubox/paubox-ruby/compare/v1.0.0...v1.1.0) (2026-09-09)


### Features

* add scheduled send support ([#26](https://github.com/Paubox/paubox-ruby/issues/26)) ([9ddb07a](https://github.com/Paubox/paubox-ruby/commit/9ddb07a20f41874a10be6e0479cb943e833b336d))


### Bug Fixes

* target the documented /v1/email and /v1/forms base URLs ([#24](https://github.com/Paubox/paubox-ruby/issues/24)) ([3a32459](https://github.com/Paubox/paubox-ruby/commit/3a324596ef8e9237d5da15246b36a21baf3df688))

## [1.0.0](https://github.com/Paubox/paubox-ruby/compare/v0.3.2...v1.0.0) (2026-08-21)

First stable release. RubyGems had been on `0.3.2` since October 2022.

### ⚠ BREAKING CHANGES

- Promotes the gem from `0.x` to a stable `1.0.0`. No public API is removed and existing code keeps working, but dependents pinned with a pessimistic `0.x` constraint will not resolve `1.0.0` without widening it. This affects `paubox_rails`, whose gemspec requires `paubox '~> 0.3'`

### 🚀 New Features

- Add `Paubox::FormsClient` for the Paubox Forms API, with `Paubox::Form` and `Paubox::FormSubmission` models
  - Public endpoints, no credential attached: `get_form`, `submit_form`
  - Form management with a scoped API key (`forms` scope, sent as `Authorization: Bearer <key>`): `list_forms`, `find_form`, `create_form`, `update_form`, `archive_form`, `unarchive_form`, `copy_form`, `form_stats`
  - Submissions: `list_submissions`, `submissions_csv`, `submission_pdf`
- The Email API no longer requires `api_user` — an API key alone authenticates

### ⚠️ Behavior Changes

- Email API base URLs move to `api.paubox.com`. `api_user` is accepted and ignored, and `Paubox::Client#api_user` is kept as a deprecated reader, so existing configuration keeps working
- The Forms API host is `api.paubox.com`, moved from the earlier `apx.paubox.com/forms`

### 🔒 Hardening

- Validate and encode caller-supplied values interpolated into Forms request paths. Authenticated endpoints require a UUID; public endpoints encode the segment instead of rejecting it
- Keep the Bearer token out of exception messages raised from Forms requests

### 🐛 Fixes

- Declare `base64` and `ostruct` as runtime dependencies. Both left the Ruby default gems (`base64` in 3.4, `ostruct` in 4.0) and `lib/` requires them, so the gem failed to load on Ruby 3.4 without them ([7299324](https://github.com/Paubox/paubox-ruby/commit/729932436a8982c11f2a71d0d2327265160317d3))

### 🎉 Enhancements

- Replace the dead Travis config with a GitHub Actions CI workflow running RSpec on Ruby 3.1 through 3.4

## v0.3.2 / 2022-10-06

### 🚀 New Features

- Add support for sending messages using dynamic templates ([#8](https://github.com/Paubox/paubox-ruby/pull/8))

## v0.3.0 / 2019-07-10

### 🎉 Enhancements

- Version bump and dependency maintenance

## v0.2.3 / 2018-10-04

### 🎉 Enhancements

- Relax the `mail` dependency to `>= 2.5`
- Declare a minimum Ruby version of 2.3

## v0.1.3 / 2018-04-30

### 🎉 Enhancements

- Relax the `mail` dependency to `>= 2.6`

## v0.1.1 / 2018-04-26

### 🐛 Fixes

- Packaging fixes following the initial release

## v0.1.0 / 2018-04-17

### 🚀 Major Release

First release of the Paubox Transactional Email SDK for Ruby.
