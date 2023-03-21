# Changelog
This file contains all the notable changes done to the Ballerina WebSubHub package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### [1.5.2] - 2023-03-21

### Fixed
- [Terminate the application when there is a panic from within the `websubhub:Service`](https://github.com/ballerina-platform/ballerina-standard-library/issues/4229)

### [1.5.1] - 2023-03-16

### Fixed
- [Ballerina `websubhub` module will fail to provide error details properly when there is a `panic` from within the `websubhub:Service`](https://github.com/ballerina-platform/ballerina-standard-library/issues/4217)

## [1.5.0] - 2022-11-29

### Fixed
- [Compiler plugin allows passing an HTTP listener with configs to listener init](https://github.com/ballerina-platform/ballerina-standard-library/issues/2782)

### Changed
- [API Docs Updated](https://github.com/ballerina-platform/ballerina-standard-library/issues/3463)

## [1.4.1] - 2022-10-30

### Fixed
- [`websubhub:HubClient` appends unwanted `/` to the service-path](https://github.com/ballerina-platform/ballerina-standard-library/issues/3564)


## [1.4.0] - 2022-09-08

### Added
- [Add `statusCode` field for `CommonResponse`](https://github.com/ballerina-platform/ballerina-standard-library/issues/2879)

### Fixed
- [Error responses are not descriptive in `websubhub:PublisherClient`](https://github.com/ballerina-platform/ballerina-standard-library/issues/2919)
- [`websubhub:CommonResponse` is not properly getting populated for responses](https://github.com/ballerina-platform/ballerina-standard-library/issues/2878)

## [1.3.0] - 2022-05-30

### Fixed
- [Compiler plugin crashes when using a new-expr with a user-defined class in the same source](https://github.com/ballerina-platform/ballerina-standard-library/issues/2815)

## [1.2.0] - 2022-01-29

### Added
- [WebSub/WebSubHub should support `readonly` parameters for remote methods](https://github.com/ballerina-platform/ballerina-standard-library/issues/2604)

## [1.0.1] - 2021-12-14

### Changed
- [Mark WebSubHub Service type as distinct](https://github.com/ballerina-platform/ballerina-standard-library/issues/2398)

## [1.0.0] - 2021-10-09

### Added
- [Add `hubMode` field to topic-registration and topic-deregistration request body](https://github.com/ballerina-platform/ballerina-standard-library/issues/1638)

## [0.2.0.beta.2]  - 2021-07-06

### Fixed 

- [Log error when return from the remote method leads to an error](https://github.com/ballerina-platform/ballerina-standard-library/issues/1449)
- [WebSubHub Compiler Plugin does not allow additional methods inside service declaration](https://github.com/ballerina-platform/ballerina-standard-library/issues/1417)
- [Fix logic issue in selecting the event-type for content-publishing](https://github.com/ballerina-platform/ballerina-standard-library/issues/1460)
- [Fix Required parameter validation for WebSubHub Service Declaration](https://github.com/ballerina-platform/ballerina-standard-library/issues/1477)

### Changed

- [Return only module specific errors from public APIs](https://github.com/ballerina-platform/ballerina-standard-library/issues/1487)

## [0.2.0-beta.1] - 2021-05-06

### Added
- [Include Kafka based WebSubHub Sample](https://github.com/ballerina-platform/ballerina-standard-library/issues/992)

### Changed
- [Make HTTP Service Class Isolated in WebSubHub](https://github.com/ballerina-platform/ballerina-standard-library/issues/1390)

### Fixed
- [Fix the listener initialization with inline configs compiler plugin error](https://github.com/ballerina-platform/ballerina-standard-library/issues/1304)
- [Include Auth Configuration to WebSubHub PublisherClient configuration](https://github.com/ballerina-platform/ballerina-standard-library/issues/1324)

## [0.2.0-alpha8] - 2021-04-22
### Added
- [Add compiler plugin to validate websubhub:Service](https://github.com/ballerina-platform/ballerina-standard-library/issues/1099)
- [Implement websubhub:ServiceConfig annotation for websubhub:Service](https://github.com/ballerina-platform/ballerina-standard-library/issues/1253)

## [0.2.0-alpha7] - 2021-04-02
### Fixed
- [Fix issue in form-url-encoded content-delivery in websubhub-client.](https://github.com/ballerina-platform/ballerina-standard-library/issues/1107)
