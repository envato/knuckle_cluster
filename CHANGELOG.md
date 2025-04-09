# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [2.3.5] - 2025-03-09

* Be explicit that an index number is expected in the lists for agents and containers ([#36](https://github.com/envato/knuckle_cluster/pull/36))

## [2.3.4] - 2023-03-06

### Fixed

* Fix the error caused by the removal of `File.exists?` in Ruby 3.2 ([#31](https://github.com/envato/knuckle_cluster/pull/31))

## [2.3.3] - 2020-05-11

### Fixed

* Fix deprecation warnings in Ruby 2.7 ([#28](https://github.com/envato/knuckle_cluster/pull/28))

## [2.0.0] - 2018-03-27

### Changed

* Refactor SCP implementation to use new syntax
* Allow SCP copy files FROM agents or containers

[unreleased]: https://github.com/envato/knuckle_cluster/compare/v2.3.5...HEAD
[2.3.5]: https://github.com/envato/knuckle_cluster/compare/v2.3.4...v2.3.5
[2.3.4]: https://github.com/envato/knuckle_cluster/compare/v2.3.3...v2.3.4
[2.3.3]: https://github.com/envato/knuckle_cluster/compare/v2.3.2...v2.3.3
