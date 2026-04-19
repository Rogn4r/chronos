# Chronos - Universal high-performance time parser for Janet
# Optimized for log processing and multiline discovery.

(def month-map
  @{"jan" 0 "feb" 1 "mar" 2 "apr" 3 "may" 4 "jun" 5
    "jul" 6 "aug" 7 "sep" 8 "oct" 9 "nov" 10 "dec" 11
    "Jan" 0 "Feb" 1 "Mar" 2 "Apr" 3 "May" 4 "Jun" 5
    "Jul" 6 "Aug" 7 "Sep" 8 "Oct" 9 "Nov" 10 "Dec" 11
    "янв" 0 "фев" 1 "мар" 2 "апр" 3 "май" 4 "июн" 5
    "июл" 6 "авг" 7 "сен" 8 "окт" 9 "ноя" 10 "дек" 11
    "Янв" 0 "Фев" 1 "Мар" 2 "Апр" 3 "Май" 4 "Июн" 5
    "Июл" 6 "Авг" 7 "Сен" 8 "Окт" 9 "Ноя" 10 "Дек" 11
    "01" 0 "02" 1 "03" 2 "04" 3 "05" 4 "06" 5
    "07" 6 "08" 7 "09" 8 "10" 9 "11" 10 "12" 11})

(defn add-months [dict] (merge-into month-map dict))

(def- time-rules
  ~{:digit (range "09")
    :n (replace (capture (some :digit)) ,scan-number)
    :d-janet (replace :n ,dec)
    :month (replace (capture (some (if-not (set " /:[]") 1))) ,|(get month-map $))
    :offset (sequence (opt (some " ")) 
                      (capture (choice "Z" "UTC" "GMT" 
                                       (sequence (set "+-") (some (choice :digit ":"))))))

    :iso (group (sequence (constant :iso) 
           :n (opt "-") :d-janet (opt "-") :d-janet
           (opt (sequence (choice "T" (some " ")) :n))
           (opt (sequence (opt ":") :n))
           (opt (sequence (opt ":") :n))
           (opt (sequence (set ".,") (capture (some :digit))))
           (opt :offset)))

    :nginx (group (sequence (constant :nginx) (opt "[") :d-janet "/" :month "/" :n ":" :n ":" :n ":" :n
             (opt (sequence (opt (some " ")) :offset)) (opt "]")))

    :syslog (group (sequence (constant :syslog) :month (some " ") :d-janet (some " ") :n ":" :n ":" :n))

    :main (choice :nginx :iso :syslog)})

(def- time-grammar (peg/compile time-rules))

(defn- parse-offset [off]
  (if (or (nil? off) (index-of (string/trim off) ["Z" "UTC" "GMT"])) 0
    (let [c (string/replace-all ":" "" (string/trim off))
          s (if (string/has-prefix? "-" c) -1 1)
          n (string/slice c 1)
          h (scan-number (string/slice n 0 2))
          m (if (> (length n) 2) (or (scan-number (string/slice n 2)) 0) 0)]
      (* s (+ (* (or h 0) 3600) (* (or m 0) 60))))))

(defn parse
  "Parses a timestamp string. Returns @{:unix :frac :format :raw} or nil."
  [s]
  (when (string? s)
    (if-let [m (peg/match time-grammar s)]
      (let [p (slice (first m) 1)
            tag (first (first m))
            res @{:format tag :raw s}]
        (case tag
          :iso (let [off (find |(and (string? $) (or (string/has-prefix? "+" $) (string/has-prefix? "-" $) (index-of (string/trim $) ["Z" "UTC" "GMT"]))) p)
                     y (get p 0) mon (get p 1) d (get p 2)
                     h (get p 3) min (get p 4) sec (get p 5) fr (get p 6)]
                 (put res :unix (- (os/mktime {:year y :month (if (number? mon) mon 0) :month-day d
                                               :hours (or h 0) :minutes (or min 0) :seconds (or sec 0)})
                                   (parse-offset off)))
                 (put res :frac (if (string? fr) (scan-number (string "0." fr)) 0)))
          :nginx (let [p-clean (if (= (first p) "[") (slice p 1) p)
                       off (find |(and (string? $) (or (string/has-prefix? "+" $) (string/has-prefix? "-" $))) p-clean)
                       [d mon y h min sec] p-clean]
                   (put res :unix (- (os/mktime {:year y :month (or mon 0) :month-day d
                                                 :hours h :minutes min :seconds sec})
                                     (parse-offset off))))
          :syslog (let [[mon d h min sec] p]
                    (when (and (number? mon) d)
                      (let [now (os/date nil true)
                            ts (os/mktime {:year (now :year) :month mon :month-day d
                                           :hours h :minutes min :seconds sec} true)]
                        (put res :unix (if (> ts (+ (os/time) 86400))
                                         (os/mktime {:year (dec (now :year)) :month mon :month-day d
                                                     :hours h :minutes min :seconds sec} true)
                                         ts))))))
        (if (res :unix) res nil))
      nil)))

(def- search-grammar 
  (peg/compile ~(sequence (thru (sequence (position) (at-least 1 ,time-rules) (position))))))

(defn find
  "Searches for a timestamp inside a line. Returns data and indices."
  [s]
  (when (string? s)
    (if-let [m (peg/match search-grammar s)] # Используем прекомпилированный PEG
      (let [start (first m)
            end (last m)
            raw-date (string/slice s start end)]
        (if-let [res (parse raw-date)]
          (merge-into res @{:start start :end end})
          nil))
      nil)))
