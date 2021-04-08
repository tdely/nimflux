Changes
=======

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

