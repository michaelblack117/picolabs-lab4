ruleset com.blacklite.wovyn_base {
  meta {
    name "Wovyn Base"
    author "Michael Black"

    use module com.blacklite.krl.twilio alias twilio

    shares __testing
  }

  global {
    temperature_threshold = 82

    __testing = {
      "queries":[ {"name": "__testing"} ],
      "events": [ {"domain": "wovyn", "type": "heartbeat", "attrs": ["genericThing"]} ]
    }
  }

  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      generic_thing = event:attrs{"genericThing"}.klog("genericThing")
      data = generic_thing{"data"}
      temp = data{"temperature"}
      time = time:now()
      statusMessage = (generic_thing.isnull()) => "missing attribute: genericThing"
                      | (temp.isnull()) => "error: unable to read temperature" | "ok"
      status = (statusMessage == "ok") => "ok" | "error"
    }

    choose status {
      ok => send_directive("Success!", {"message": "Successfully read a temperature from the wovyn thermometer", "Temperature Data": temp})
      error => send_directive("Error!", {"message": statusMessage})
    }

    fired {
      raise wovyn event "new_temperature_reading"
        attributes {"timestamp": time, "temperature": temp}
        if (status == "ok")
    }

  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      time = event:attrs{"timestamp"}
      temp = event:attrs["temperature"]
      tempF = temp[0]{"temperatureF"}
      violation = (tempF > temperature_threshold) => true | false
      status = (violation) => "bad" | "good"
    }

    choose status {
      good => send_directive("Temperature Reading", {"message": "Tempurature looks good", "temperatureF": tempF, "timestamp": time});
      bad => send_directive("Temperature Reading", {"message": "Warning! Temperature Violation!"});
    }

    fired {
      raise wovyn event "threshold_violation"
        attributes {"timestamp": time, "temperatureF": tempF}
        if violation
    }



  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      tempF = event:attrs{"temperatureF"}
      message = "Warning: Temperature Threshold Violation! Reading: " + tempF
    }

    always {
      raise twilio event "send_message"
        attributes {"to": "+17193590627", "from": "+17193966763", "message": message}
    }
  }
}
