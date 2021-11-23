Changes
=======

[1.0.3] - 2021-11-23
--------------------

### Changed

* Fixed not being able to pass `SslContext` to `ssl=` in `newAsyncInfluxClient`.
* Fixed not being able to get a string representation of `AsyncInfluxClient`
  through `$`.
* Fixed `setBasicAuth` and `setTokenAuth` not working with `AsyncInfluxClient`.

[1.0.2] - 2021-07-01
--------------------

### Changed

* `close` was func instead of proc causing an issue with the `strictFunc` pragma
  has it may have possible side effects. `close` is now correctly proc.

[1.0.1] - 2021-06-29
--------------------

### Changed

* Fix value of tags being erroneously quoted.

[1.0.0] - 2021-06-28
--------------------

### Added

* Asynchronous functionality has been added through `AsyncInfluxClient`.
* Custom `SslContext` can now be used for HTTP actions.
* The module now exports some necessary parts from the httpclient module.

### Changed

* The Influx client now has a persistent HTTP client instead of creating a new
  instance for each request. The proc `close` has been added for closing the
  internal HTTP client.
* Requests no longer returns both the HTTP response and the "Influx status",
  just the HTTP response. The status can be created manually by using the
  exported `toInfluxStatus` proc.

[0.1.3] - 2021-04-08
--------------------

### Added

* Implemented `$` proc for InfluxClient.

[0.1.2] - 2021-03-11
--------------------

### Changed

* Fixed socket fd leaking due to not closing httpClient after requests. Leaking
  will still occurr on failed connections due to an upstream bug, see:
  https://github.com/nim-lang/Nim/issues/12381

[0.1.1] - 2021-03-01
--------------------

### Changed

* Fixed InfluxClient not being GC-safe.

[0.1.0] - 2021-02-27
--------------------

### Added

* Initial release
