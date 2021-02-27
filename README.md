Nimflux
=======

InfluxDB API client library for Nim.

Nimflux provides the InfluxClient type for communicating with the InfluxDB API.
InfluxClient can be used to `ping`, `write`, `query`, or send a custom `request`.
The DataPoint type is used to create measurements for `write`, although it is
also possible use your own Line Protocol string.

```nim
import nimflux

var data = DataPoint(measurement: "temp")
data.addTag("loc", "home")
data.addField("ambient", 22.0)

var client = InfluxClient("localhost", "nimtest")
var (resp, status) = client.write(data)
assert status == Ok
(resp, status) = client.query("select * from temp")
echo resp.body
```
