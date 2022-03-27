discard """
  cmd: "nim c -r $options $file"
  output: '''
hello!
"hello!"
3i
1.0
t
f
msr,tag=tval field="fval" 1
msr field="fval" 1
msr,tag=tval field="fval"
'''
"""
import tables

import nimflux

block addTag:
  let point = DataPoint()
  point.addTag("tag", "hello!")
  echo point.tags["tag"]

block addField_string:
  let point = DataPoint()
  point.addField("fieldStr", "hello!")
  echo point.fields["fieldStr"]

block addField_int:
  let point = DataPoint()
  point.addField("fieldInt", 3)
  echo point.fields["fieldInt"]

block addField_float:
  let point = DataPoint()
  point.addField("fieldFloat", 1.0)
  echo point.fields["fieldFloat"]

block addField_bool:
  let point = DataPoint()
  point.addField("fieldTrue", true)
  point.addField("fieldFalse", false)
  echo point.fields["fieldTrue"]
  echo point.fields["fieldFalse"]

block dollar_full:
  let point = DataPoint(measurement: "msr", tags: {"tag": "tval"}.toTable, timestamp: 1)
  point.addField("field", "fval")
  echo $point

block dollar_sans_tags:
  let point = DataPoint(measurement: "msr", timestamp: 1)
  point.addField("field", "fval")
  echo $point

block dollar_sans_timestamp:
  let point = DataPoint(measurement: "msr", tags: {"tag": "tval"}.toTable)
  point.addField("field", "fval")
  echo $point
