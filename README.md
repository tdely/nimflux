Nimflux
=======

Nimflux is an InfluxDB API client library for Nim that can be used to `ping`,
`write`, `query`, or send custom `request`s. The `DataPoint` type is used to
easily create measurements for `write`, but it's also possible to send your own
Line Protocol string should the need arise.

```nim
import nimflux

var data = DataPoint(measurement: "temp")
data.addTag("loc", "home")
data.addField("ambient", 22.0)

var client = newInfluxClient("localhost", "nimtest")
var resp = client.write(data)
assert resp.code.toInfluxStatus == Ok
resp = client.query("select * from temp")
echo resp.body
```

Asynchronous actions are also supported through `AsyncInfluxClient`:

```nim
import asyncdispatch, nimflux

var data = DataPoint(measurement: "temp")
data.addTag("loc", "home")
data.addField("ambient", 22.0)

proc asyncProc(data: DataPoint): Future[AsyncResponse] {.async.} =
  var client = newAsyncInfluxClient("localhost", "nimtest")
  var resp = await client.write(data)
  assert resp.code.toInfluxStatus == Ok
  return await client.query("select * from temp")

echo asyncProc(data).waitFor().body.waitFor()
```
