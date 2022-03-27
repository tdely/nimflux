discard """
  cmd: "nim c -r $options $file"
  output: '''
204 No Content
Ok
400 Bad Request
BadRequest
204 No Content
Ok
204 No Content
Ok
204 No Content
Ok
400 Bad Request
BadRequest
200 OK
Ok
204 No Content
'''
"""
import asyncdispatch, httpclient, os, strutils

import nimflux

var
  influxdbHost = getEnv("INFLUXDB_HOST", "127.0.0.1")
  influxdbPort = parseInt(getEnv("INFLUXDB_PORT", "8086"))
  influxdbName = getEnv("INFLUXDB_NAME", "nimtest")

block:
  var client = newInfluxClient(influxdbHost, "", influxdbPort)
  defer: client.close()
  discard client.query("CREATE DATABASE " & influxdbName)

block InfluxClient:
  var client = newInfluxClient(influxdbHost, influxdbName, influxdbPort)
  defer: client.close()

  block ping:
    var resp = client.ping()
    echo resp.code
    echo resp.code.toInfluxStatus

  block write_incorrect:
    var resp = client.write("lorem ipsum")
    echo resp.code
    echo resp.code.toInfluxStatus

  block write_string:
    var resp = client.write("tm tf=1i")
    echo resp.code
    echo resp.code.toInfluxStatus

  block write_DataPoint:
    var d = DataPoint(measurement: "tm")
    d.addField("tf", 1)
    var resp = client.write(d)
    echo resp.code
    echo resp.code.toInfluxStatus

  block write_seq_DataPoint:
    var d1 = DataPoint(measurement: "tm")
    var d2 = DataPoint(measurement: "tm")
    d1.addField("tf", 1)
    d2.addField("tf", 2)
    var resp = client.write(@[d1, d2])
    echo resp.code
    echo resp.code.toInfluxStatus

  block query_incorrect:
    var resp = client.query("")
    echo resp.code
    echo resp.code.toInfluxStatus

  block query_OK:
    var resp = client.query("select * from tm")
    echo resp.code
    echo resp.code.toInfluxStatus

block AsyncInfluxClient:
  var client = newAsyncInfluxClient(influxdbHost, influxdbName, influxdbPort)
  defer: client.close()

  block write_DataPoint:
    var d = DataPoint(measurement: "tm")
    d.addField("tf", 1)
    var future = client.write(d)
    var resp = waitFor(future)
    echo resp.code
