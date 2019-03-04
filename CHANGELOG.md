# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased & outstanding issues]
- None

## [1.6.2] - 2019-03-04
When pinning Datadog Agent versions, previous buildpacks pulled old versions from the buildpack cache causing availability to be unreliable. The buildpack now pulls old versions from apt.

### Changed
- The buildpack now pulls old versions from apt.
- Updated documentation around system metrics.

## [1.6.1]
Converted to Gigalixir; aligning releases with Heroku Datadog Buildpack when possible.
