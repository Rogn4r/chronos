(import /src/chronos :as chronos)
(defn assert-success [res label]
  (if (and res (get res :unix))
    (let [ts (res :unix)
          d (os/date ts true)
          # Определяем зону для вывода (например, MSK или UTC)
          zone (if (os/date ts :dst) "Local-DST" "Local")
          pretty-date (string/format "%d-%02d-%02d %02d:%02d:%02d (%s)" 
                                     (d :year) (inc (d :month)) (inc (d :month-day))
                                     (d :hours) (d :minutes) (d :seconds) zone)]
      (print (string/format "[PASS] %-30s | Unix: %d | Date: %s" label ts pretty-date)))
    (do 
      (print (string/format "[FAIL] %s" label) (if res (string " Result: " (res :format)) "")) 
      (os/exit 1))))

(print "Chronos Comprehensive Test Suite")
(print "-------------------------------")

# 1. ISO8601 Parsing
(assert-success (chronos/parse "2026-04-19T13:20:00Z") "ISO8601 Strict Z")
(assert-success (chronos/parse "2026-04-19T13:20:00+0800") "ISO8601 Strict +0800")
(assert-success (chronos/parse "2026-04-19T13:20:00+03:00") "ISO8601 Offset with colon")
(assert-success (chronos/parse "2026-04-19T13:20:00.123Z") "ISO8601 Milliseconds")
(assert-success (chronos/parse "2026-04-19T13:20:00.999999Z") "ISO8601 Microseconds")
(assert-success (chronos/parse "2026-04-19") "ISO8601 Date Only")

# 2. Database & Application Styles
(assert-success (chronos/parse "2026-04-19 18:30:10 -0800") "PostgreSQL Space Separated")
(assert-success (chronos/parse "2026-04-19 17:53:22 INFO [main]") "Java Standard App Log")

# 3. Edge Cases
(assert-success (chronos/parse "2026-04-19T23:59:59-11:00") "Max West Offset")
(assert-success (chronos/parse "2026-12-31T24:00:00Z") "Midnight Rollover")

# 4. Syslog (Multilingual Support)
(assert-success (chronos/parse "May 27 10:30:00") "Syslog English Titlecase")
(assert-success (chronos/parse "apr 19 14:37:24") "Syslog English Lowercase")
(assert-success (chronos/parse "Май 27 10:30:00") "Syslog Russian Titlecase")
(assert-success (chronos/parse "апр 19 14:37:24") "Syslog Russian Lowercase")

# 5. Extraction Tests (chronos/find)
(let [log `93.180.71.3 - - [17/May/2015:08:05:32 +0300] "GET / HTTP/1.1" 200`]
  (let [res (chronos/find log)]
    (assert-success res "Find Nginx in log")
    (if (= ((os/date (res :unix)) :month) 4)
      (print "[PASS] Nginx month index correct (May=4)")
      (do (print "[FAIL] Nginx month index mismatch") (os/exit 1)))))

(let [log `apr 19 15:32:01 host-name service[123]: operation failed`]
  (let [res (chronos/find log)]
    (assert-success res "Find Journald in log")
    (if (= ((os/date (res :unix)) :month) 3)
      (print "[PASS] Journal month index correct (Apr=3)")
      (do (print "[FAIL] Journal month index mismatch") (os/exit 1)))))

(print "-------------------------------")
(print "All tests passed successfully!")

