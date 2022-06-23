;;; org-habit-stats.el --- compute info about habits  -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 null
;;
;; Author: ml729
;; Created: October 22, 2021
;; Modified: October 22, 2021
;; Version: 0.0.1
;; Keywords:
;; Homepage:
;; Package-Requires: ((emacs "24.4"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;
;;
;;; Code:

(require 'org-habit)
(require 'cl-lib)
(require 'seq)
(require 'org-habit-stats-chart)

;; User can choose which stats to compute
(defvar org-habit-stats-list 1)
;; (defvar org-habit-stats-graph-drawer-name)

(defcustom org-habit-stats-insert-graph-in-file t
  "Whether or not to insert ascii graph of habit scores in file."
  :group 'org-habit-stats
  :type 'boolean)

(defcustom org-habit-stats-graph-drawer-name "GRAPH"
  "Name of drawer that stores habit graph."
  :group 'org-habit-stats
  :type 'string)


(defcustom org-habit-stats-graph-colors-for-light-list
  '("#ef7969"
    "#49c029"
    "#ffcf00"
    "#7090ff"
    "#e07fff"
    "#70d3f0")
  "Colors to use for bars of habit bar graph for light themes. The default colors are
Modus Vivendi's colors for graphs. The original value of
chart-face-color-list is unaffected.")

(defcustom org-habit-stats-graph-colors-for-dark-list
  '("#b52c2c"
    "#24bf00"
    "#f7ef00"
    "#2fafef"
    "#bf94fe"
    "#47dfea")
  "Colors to use for bars of habit bar graph for dark themes. The default colors are
Modus Vivendi's colors for graphs. The original value of
chart-face-color-list is unaffected.")

(defvar org-habit-stats-graph-face-list nil
  "Faces used for bars in graphs, generated from org-habit-stats-graph-colors-for-light-list
or org-habit-stats-graph-colors-for-dark-list based on the background type.")

(defcustom org-habit-stats-graph-width 70
  "Width of x-axis of graph (in columns), not including origin.")

(defcustom org-habit-stats-graph-height 12
  "Height of y-axis of graph (in line numbers), not including origin.")

(defcustom org-habit-stats-graph-left-margin 5
  "Number of columns to the left of y-axis.")


(defcustom org-habit-stats-graph-min-num-bars 3
  "How many bars to shift left when the bar graph is truncated.")
(defcustom org-habit-stats-graph-current-offset 0
  "How many bars to shift left when the bar graph is truncated.")
(defcustom org-habit-stats-graph-number-months 5
  "How many months to display when graph's x-axis is months.")
(defcustom org-habit-stats-graph-number-weeks 10
  "How many weeks to display when graph's x-axis is weeks.")
(defcustom org-habit-stats-graph-number-days 15
  "How many days to display when graph's x-axis is days.")

(defcustom org-habit-stats-view-order '(statistics graph calendar)
  "Output from org-habit-parse-todo of currently viewed habit.")

(defcustom org-habit-stats-graph-data-horizontal-char ?-
  "Character used to draw horizontal lines for a graph's data.")

(defcustom org-habit-stats-graph-data-vertical-char ?|
  "Character used to draw vertical lines for a graph's data.")

(defcustom org-habit-stats-graph-axis-horizontal-char ?-
  "Character used to draw horizontal lines for a graph's axes.")

(defcustom org-habit-stats-graph-axis-vertical-char ?|
  "Character used to draw vertical lines for a graph's axes.")

(defcustom org-habit-stats-months-names-alist
  '(("Jan" . 1)
    ("Feb" . 2)
    ("Mar" . 3)
    ("Apr" . 4)
    ("May" . 5)
    ("Jun" . 6)
    ("Jul" . 7)
    ("Aug" . 8)
    ("Sep" . 9)
    ("Oct" . 10)
    ("Nov" . 11)
    ("Dec" . 12))
  "Month names used in graphs.")

(defcustom org-habit-stats-days-names-alist
  '(("Sun" . 1)
    ("Mon" . 2)
    ("Tue" . 3)
    ("Wed" . 4)
    ("Thu" . 5)
    ("Fri" . 6)
    ("Sat" . 7))
  "Day names used in graphs.")

(defcustom org-habit-stats-graph-date-format
  "%m/%d"
  "Date format used in graphs for dates in graphs.")

(defcustom org-habit-stats-stat-functions-alist
  '((org-habit-stats-exp-smoothing-list-score . "Strength")
     ;; (org-habit-stats-present-streak . "Current-Streak")
     ;; (org-habit-stats-present-unstreak . "Current Unstreak")
     ;; org-habit-stats-recent-unstreak
     ;; (org-habit-stats-record-streak . "Record Streak")
     (org-habit-stats-alltime-total . "Total Completions")
     (org-habit-stats-alltime-percentage . "Total Percentage"))
  "Alist mapping stat functions to their names. All stat
functions take in the original parsed habit data (outputted by
org-habit-parse-todo) and the full habit history (outputted by
org-habit-stats-get-full-history-new-to-old)")

(defcustom org-habit-stats-graph-functions-alist
  '((org-habit-stats-graph-completions-per-month . ("m"
                                                   "Monthly Completions"
                                                   "Months"
                                                   "Completions"
                                                   vertical
                                                   5))
    (org-habit-stats-graph-completions-per-week . ("w"
                                                   "Weekly Completions"
                                                   "Weeks"
                                                   "Completions"
                                                   vertical
                                                   10))
    (org-habit-stats-graph-completions-per-weekday . ("d"
                                                   "Completions by Day"
                                                   "Day"
                                                   "Completions"
                                                   vertical
                                                   7)))
  "Alist mapping graph functions to a list containing the key
that invokes the function, the title of the graph, the name of
the x-axis, the name of the y-axis, the graph direction and the
max number of bars to show at a time.")

(defconst org-habit-stats-buffer "*Org-Habit-Stats*"
  "Name of the buffer used for displaying stats, calendar, and graphs.")

(defconst org-habit-stats-calendar-buffer "*Org-Habit-Stats Calendar*"
  "Name of the buffer used for the calendar.")

(defcustom org-habit-stats-graph-default-func 'org-habit-stats-graph-completions-per-week
  "Current graph function used in org habit stats buffer.")

(defvar org-habit-stats-current-habit-data nil
  "Output from org-habit-parse-todo of currently viewed habit.")

(defvar org-habit-stats-graph-current-func nil
  "Current graph function used in org habit stats buffer.")

(defvar org-habit-stats-graph-text-alist
  '(org-habit-stats-graph-monthly-completions . ("Monthly Completions" "Months" "Completions"))
  "Alist mapping graph functions to a list containing the graph title,
x-axis name, y-axis name.")

;; (defvar org-habit-stats-graph-keys-alist
;;   "Alist mapping graph keys to graph functions.")

;;; Faces
(defface org-habit-stats-graph-label
  '((t (:inherit default)))
  "Face for a habit graph's axis labels."
  :group 'org-habit-stats)

(defface org-habit-stats-graph-name
  '((t (:weight bold)))
  "Face for a habit graph's axis name."
  :group 'org-habit-stats)

(defface org-habit-stats-graph-title
  '((t (:weight bold)))
  "Face for a habit graph's title."
  :group 'org-habit-stats)

(defface org-habit-stats-calendar-completed
  '((t (:background "#e0a3ff")))
  "Face for days in the calendar where the habit was completed."
  :group 'org-habit-stats)

(defun org-habit-stats-dates-to-binary (tasks)
  "Return binary version of TASKS from newest to oldest, where
TASKS is a list of all the past dates this habit was marked
closed. Assumes the dates logged for the habit are in order,
newest to oldest."
  (let* ((bin-hist '()))
    (while (> (length tasks) 1)
      (push 1 bin-hist)
      (let* ((next (pop tasks))
             (diff (- (nth 0 tasks) next)))
        (while (> diff 1)
          (push 0 bin-hist)
          (setq diff (- diff 1)))))
    (if (= (length tasks) 1) (push 1 bin-hist))
    bin-hist))

;; (defun org-habit-stats-dates-to-binary (history)
;;   (let* ((today (org-today))
;;          day (pop history)
;;          (bin-hist '()))
;;     (while history
;;     (push (cons day 1) bin-hist)
;;     (setq day (1+ day))
;;     (while (< day (car history))
;;       (push (cons day 0) bin-hist)
;;       (setq day (1+ day))))

;;     (let ((diff (- (car history) day)))
;;       (if (> diff 1)
;;           (dotimes (i (1- diff))
;;             (push (cons (+ day i 1) 0))))
;;     (if (> (- (car history) day) 1)
;;         (dotimes i (1- (-))
;;                  )))))
(defun org-habit-stats-get-full-history-new-to-old (history)
  (let* ((today (org-today))
         (history (add-to-list 'history (1+ today)))
         (bin-hist nil))
    (seq-reduce
     (lambda (a b)
       (push (cons a 1) bin-hist)
       (setq a (1+ a))
       (while (< a b)
         (push (cons a 0) bin-hist)
         (setq a (1+ a)))
       b)
     history
     (car history))
    bin-hist))
(defun org-habit-stats-get-full-history-old-to-new (history)
  (reverse (org-habit-stats-get-full-history-new-to-old history)))

;; Stats
(defun org-habit-stats--streak (h)
  (if (= (cdr (pop h)) 1)
      (1+ org-habit-stats--streak h)
    0))
(defun org-habit-stats-streak (history &optional habit-data)
  "Returns the current streak. If habit is completed today,
include it. If not, begin counting current streak from
yesterday."
  (if (= (cdr (pop history)) 1)
      (1+ (org-habit-stats-streak history))
    (org-habit-stats-streak history)))

(defun org-habit-stats--record-streak-full (history &optional habit-data)
  "Returns (a b) where a is the record streak,
   b is the day the record streak occurred."
  (let ((record-streak 0)
        (record-day 0)
        (curr-streak 0)
        (curr-streak-start 0)
        (curr-day 0))
    (while history
      (if (= (cdr (pop history)) 1)
          (progn
            (when (= curr-streak 0)
              (setq curr-streak-start curr-day))
            (setq curr-streak (1+ curr-streak)))
        (setq curr-streak 0))
      (when (> curr-streak record-streak)
        (setq record-streak curr-streak)
        (setq record-day curr-streak-start))
      (setq curr-day (1+ curr-day)))
    (cons record-streak (org-date-to-gregorian (- (org-today) record-day)))))

(defun single-whitespace-only (s)
  (string-join
   (seq-filter (lambda (x) (if (> (length x) 0) t))
               (split-string s " "))
   " "))

(defun org-habit-stats-record-streak-format (history &optional habit-data)
  (let* ((record-data (org-habit-stats--record-streak-full history habit-data))
         (record-streak (car record-data))
         (record-day (cdr record-data)))
    (concat (number-to-string record-streak)
            ", on "
            (single-whitespace-only (org-agenda-format-date-aligned record-day)))))

(defun org-habit-stats--N-day-total (history N)
  (if (and (> N 0) history)
      (if (= (cdr (pop history)) 1)
          (1+ (org-habit-stats-N-day-total history (1- N)))
        (org-habit-stats-N-day-total history (1- N)))
    0))
(defun org-habit-stats--N-day-percentage (history N habit-data)
  (let ((repeat-len (nth 1 habit-data)))
  (/ (org-habit-stats-N-day-total history N) (/ (float N) repeat-len))))

(defun org-habit-stats-30-day-total (history &optional habit-data)
  (org-habit-stats-N-day-percentage history 30))

(defun org-habit-stats-365-day-total (history &optional habit-data)
  (org-habit-stats-N-day-percentage history 365))

(defun org-habit-stats-alltime-total (history habit-data)
  (length (nth 4 habit-data)))

(defun org-habit-stats-alltime-percentage (history habit-data)
  (let ((repeat-len (nth 1 habit-data)))
  (/ (length (nth 4 habit-data)) (/ (float (length history)) repeat-len))))

(defun org-habit-stats-exp-smoothing-list--full (history &optional habit-data)
  "Returns score for a binary list HISTORY,
   computed via exponential smoothing. (Inspired by the open
   source Loop Habit Tracker app's score.)"
  (let* ((history (reverse history))
         (scores '(0))
         (freq 1.0)
         (alpha (expt 0.5 (/ (sqrt freq) 13))))
    (while history
      (push (+ (* alpha (nth 0 scores))
               (* (- 1 alpha) (cdr (pop history)))) scores))
    (setq scores (mapcar (lambda (x) (* 100 x)) scores))
    scores))
(defun org-habit-stats-exp-smoothing-list-score (history &optional habit-data)
  (nth 0 (org-habit-stats-exp-smoothing-list--full history habit-data)))

(defun org-habit-stats-get-freq (seq &optional key-func value-func)
  "Return frequencies of elements in SEQ. If KEY-FUNC, use
KEY-FUNC to produce keys for hash table. Credit to
https://stackoverflow.com/a/6050245"
  (let ((h (make-hash-table :test 'equal))
        (freqs nil)
        (value-func (if value-func value-func (lambda (x) 1))))
    (dolist (x seq)
      (let ((key (if key-func (funcall key-func x) x)))
        (puthash key (+ (gethash key h 0) (funcall value-func x)) h)))
    (maphash #'(lambda (k v) (push (cons k v) freqs)) h)
    freqs))

(defun org-habit-stats-transpose-pair-list (a)
  (cons (mapcar 'car a) (mapcar 'cdr a)))

(defun org-habit-stats-graph-count-per-category (history category-func predicate-func format-func)
  "For each date in HISTORY, get its category (e.g. which month,
week, day of the week, etc.) using CATEGORY-FUNC, get counts per
category, sort categories with PREDICATE-FUNC, and convert
categories to readable names with FORMAT-FUNC. Returns a pair of
two lists, the first containing names of the categories, the
second containing the corresponding counts per category."
  (org-habit-stats-transpose-pair-list
  (mapcar (lambda (x) (cons (funcall format-func (car x)) (cdr x)))
          (sort (org-habit-stats-get-freq
                 (mapcar (lambda (x) (cons (funcall category-func (car x)) (cdr x)))
                         (org-habit-stats-get-full-history-old-to-new history))
                 (lambda (x) (car x))
                 (lambda (x) (cdr x)))
                (lambda (x y) (funcall predicate-func (car x) (car y)))))))

(defun org-habit-stats-graph-completions-per-month (history)
  "Returns a pair of lists (months . counts)."
  (org-habit-stats-graph-count-per-category
   history
   (lambda (d) (let ((day (calendar-gregorian-from-absolute d)))
                     (list (car day) (caddr day)))) ;; converts absolute date to list (month year)
   (lambda (m1 m2) (cond ((< (nth 1 m1) (nth 1 m2)) t)
                         ((= (nth 1 m1) (nth 1 m2)) (if (< (nth 0 m1) (nth 0 m2)) t nil))
                         (t nil)))
   (lambda (m) (car (rassoc (nth 0 m) org-habit-stats-months-names-alist)))))

(defun org-habit-stats-graph-completions-per-week (history)
  "Returns a pair of lists (weeks . counts)."
  (org-habit-stats-graph-count-per-category
   history
   (lambda (d) (- d (mod d 7))) ;; converts absolute date to the sunday before or on; (month day year) format
   (lambda (d1 d2) (< d1 d2))
   (lambda (d) (let ((time (days-to-time d)))
                 (format-time-string org-habit-stats-graph-date-format time)))))

(defun org-habit-stats-graph-completions-per-weekday (history)
  "Returns a pair of lists (weeks . counts)."
  (org-habit-stats-graph-count-per-category
   history
   (lambda (d) (mod d 7))
   (lambda (m1 m2) (< m1 m2))
   (lambda (m) (car (rassoc (1+ m) org-habit-stats-days-names-alist)))))

(defun org-habit-stats-graph-completions-test (history)
  (org-habit-stats-graph-count-per-category
   history
   (lambda (d) 1)
   (lambda (m1 m2) t)
   (lambda (m) "hi")
   ))

;; (defun org-habit-stats-graph-completions-per-week (history)
;;   "Returns a pair of lists (months . counts)."
;;   (org-habit-stats-graph-count-per-category
;;    history
;;    (lambda (d) (let ((day (calendar-gregorian-from-absolute d))
;;                      (list (car d) (caddr d))))) ;; converts absolute date to list (month year)
;;    (lambda (m1 m2) (cond ((> (nth 1 m1) (nth 1 m2)) t)
;;                          ((= (nth 1 m1) (nth 1 m2)) (if (> (nth 0 m1) (nth 0 m2)) t nil))
;;                          (t nil)))
;;    (lambda (m) (rassoc (nth 0 m) parse-time-months))))

(defun org-habit-stats-update-score ()
  (interactive)
  (when (org-is-habit-p (point))
    (let ((history (org-habit-stats-dates-to-binary
                                 (nth 4 (org-habit-parse-todo (point))))))
    (org-set-property "SCORE"
                      (number-to-string
                       (org-habit-stats-exp-smoothing-list-score
                        history)))
    (org-set-property "STREAK"
                      (number-to-string
                       (org-habit-stats-streak
                        history)))
    (org-set-property "MONTHLY"
                      (number-to-string
                       (org-habit-stats-30-day-total
                        history)))
    (org-set-property "YEARLY"
                      (number-to-string
                       (org-habit-stats-365-day-total
                        history))))))


(defun org-habit-stats-number-to-string-maybe (x)
  (cond ((integerp x) (format "%d" x))
        ((floatp x) (format "%.5f" x))
        (t x)))

(defun org-habit-stats-update-score-2 ()
  "Update score, streak, monthly, and yearly properties of a habit task
   with the corresponding statistics, and update graph of habit score."
  (interactive)
  (when (org-is-habit-p (point))
    (let ((history (org-habit-stats-dates-to-binary
                                 (nth 4 (org-habit-parse-todo (point))))))
      (mapcar (lambda (prop-func)
                ;; (print (cdr prop-func))
                (org-set-property (car prop-func)
                                  (org-habit-stats-number-to-string-maybe
                                   (funcall (cdr prop-func) history))))
              '(("SCORE" . org-habit-stats-exp-smoothing-list-score)
                ("CURRENT_STREAK" . org-habit-stats-streak)
                ("MONTHLY" . org-habit-stats-30-day-total)
                ("YEARLY" . org-habit-stats-365-day-total)
                ("RECORD_STREAK" . org-habit-stats-record-streak-format)))
      (org-habit-stats-update-graph history))))

(defun org-habit-stats-format-property-name (s)
  "Replace spaces with underscores in string S."
  (replace-regexp-in-string "[[:space:]]" "_" s))
(defun org-habit-stats-update-properties ()
  (interactive)
  (when (org-is-habit-p (point))
    (let* ((habit-data (org-habit-parse-todo (point)))
           (history (org-habit-stats-get-full-history-new-to-old (nth 4 habit-data)))
           (statresults (org-habit-stats-calculate-stats habit-data history)))
      (dolist (x statresults)
        (org-set-property (cons x)
                          (org-habit-stats-number-to-string-maybe (cdr x)))))))

;; (add-hook 'org-after-todo-state-change-hook 'org-habit-stats-update-score)
;; (advice-add 'org-todo :after (lambda (x) (org-habit-stats-update-score-2)))
(advice-add 'org-store-log-note :after 'org-habit-stats-update-score-2)
;; Create temp gnu plot file

;; Send gnu plot file to gnu plot and get graph in current buffer


;; Create org habit stats display buffer
(defun org-habit-stats-update-graph (history)
  (interactive)
  (let* ((gnuplot-buf (generate-new-buffer "*Org Habit Stats*"))
         (data-file (make-temp-file "org-habit-stats-score-monthly-data"))
         (output-file (make-temp-file "org-habit-stats-graph-output")))
    ;;insert
    (with-temp-file data-file
      (insert
       (let ((enum 0))
         (string-join
          (mapcar (lambda (x) (progn (setq enum (1+ enum)) (format "%d %d" enum x)))
                    (reverse (org-habit-stats-exp-smoothing-list--full history)))
          "\n")))
      (insert "\n"))
    (with-current-buffer gnuplot-buf
      (gnuplot-mode)
      (insert "set term dumb\n")
      (insert (format "set output '%s'\n" output-file))
      (insert (format "plot '%s' w dots\n" data-file))
      (save-window-excursion (gnuplot-send-buffer-to-gnuplot)))
    ;; read from output file
    (let ((graph-content (concat "#+BEGIN_SRC\n"
                                 (substring (org-file-contents output-file) 1)
                                 "\n#+END_SRC\n")))
            (org-habit-stats-insert-drawer org-habit-stats-graph-drawer-name graph-content))
      (delete-file data-file)
      (delete-file output-file)
      (kill-buffer gnuplot-buf)))

(defun org-habit-stats--find-drawer-bounds (drawer-name)
  "Finds and returns the start and end positions of the first
   drawer of the current heading with name DRAWER-NAME."
  (save-excursion
  (let* ((heading-pos (progn (org-back-to-heading) (point)))
         (graph-beg-pos (progn
                          (search-forward-regexp (format ":%s:" drawer-name) nil t)
                          (match-beginning 0)))
         (graph-end-pos (search-forward ":END:"))
         (graph-beg-pos-verify (progn
                                 (search-backward-regexp ":GRAPH:" nil t)
                                 (match-beginning 0)))
         (heading-pos-verify (progn (org-back-to-heading) (point))))
    (when (and heading-pos heading-pos-verify
               graph-beg-pos graph-beg-pos-verify graph-end-pos)
      (when (and (= heading-pos heading-pos-verify)
                 (= graph-beg-pos graph-beg-pos-verify))
        (cons graph-beg-pos graph-end-pos))))))
(defun org-habit-stats--remove-drawer (drawer-name)
  (let ((bounds (org-habit-stats--find-drawer-bounds drawer-name)))
    (when bounds
      (delete-region (car bounds) (cdr bounds))
      t)))

(defun org-habit-stats--skip-property-drawer ()
  (let* ((property-pos (search-forward-regexp ":PROPERTIES:" nil t)))
         (when property-pos
           (search-forward-regexp ":END:")
           (forward-line))))

(defun org-habit-stats-insert-drawer (drawer-name drawer-contents)
  "Inserts drawer DRAWER-NAME with contents DRAWER-CONTENTS.
   It is placed after the property drawer if it exists."
  (org-with-wide-buffer
   (org-habit-stats--remove-drawer drawer-name)
   (if (or (not (featurep 'org-inlinetask)) (org-inlinetask-in-task-p))
       (org-back-to-heading-or-point-min t)
     (org-with-limited-levels (org-back-to-heading-or-point-min t)))
   (if (org-before-first-heading-p)
       (while (and (org-at-comment-p) (bolp)) (forward-line))
     (progn
       (forward-line)
       (when (looking-at-p org-planning-line-re) (forward-line))
       (org-habit-stats--skip-property-drawer)))
   (when (and (bolp) (> (point) (point-min))) (backward-char))
   (let ((begin (if (bobp) (point) (1+ (point))))
         (inhibit-read-only t))
     (unless (bobp) (insert "\n"))
     (insert (format ":%s:\n%s:END:" drawer-name drawer-contents))
     (org-flag-region (line-end-position 0) (point) t 'outline)
     (when (or (eobp) (= begin (point-min))) (insert "\n"))
     (org-indent-region begin (point))
     (org-hide-drawer-toggle))))

;; mode
(define-derived-mode org-habit-stats-mode special-mode "Org-Habit-Stats"
  "A major mode for the org-habit-stats window.
\\<org-habit-stats-mode-map>\\{org-habit-stats-mode-map}"
  (setq buffer-read-only nil
        buffer-undo-list t
        indent-tabs-mode nil)
  (make-local-variable 'current-org-habit)
  (setq org-habit-stats-graph-current-offset 0)
  (if org-habit-stats-graph-default-func
        (setq org-habit-stats-graph-current-func org-habit-stats-graph-default-func)
    (setq org-habit-stats-graph-current-func (caar org-habit-stats-graph-functions-alist)))
  (setq org-habit-stats-graph-face-list (org-habit-stats-graph-create-faces))
  )
(defvar org-habit-stats-mode-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map "q"   'org-habit-stats-exit)
    (dolist (x org-habit-stats-graph-functions-alist)
      (let ((graph-func (car x))
            (graph-key (cadr x)))
        (define-key (kbd graph-key) (org-habit-stats-switch-graph graph-func))
        )
      )
    )
  "Keymap for `org-habit-stats-mode'.")
(defun org-habit-stats-switch-graph (graph-func)
  (setq org-habit-stats-graph-current-func graph-func)
  (setq org-habit-stats-graph-current-offset 0)
  (org-habit-stats-refresh-buffer))

(defun org-habit-stats-refresh-buffer ())

(defun org-habit-stats-exit ()
  (interactive)
  (kill-buffer org-habit-stats-calendar-buffer)
  (kill-buffer org-habit-stats-buffer))

;; creating the habit buffer
(defun org-habit-stats--insert-divider ()
    (insert (make-string (max 80 (window-width)) org-agenda-block-separator))
    (insert (make-string 1 ?\n)))
(defun org-habit-stats-create-habit-buffer (habit-title habit-data)
  "Creates buffer displaying:
   - Calendar where days habit is done are marked
   - Graph of habit score or histogram of habit totals monthly/weekly
   - Various habit statistics"
  (let* ((buff (current-buffer))
        (completed-history (nth 4 habit-data))
        (full-history (org-habit-stats-get-full-history-new-to-old completed-history))
        )
    (switch-to-buffer (get-buffer-create org-habit-stats-buffer))
    (org-habit-stats-mode)
    ;;; inject habit data
    ;; (insert
    ;;  (propertize "Run a mile\n" 'face 'bold))
    ;; (insert "Score: 5\tCurrent Streak: 25\t Total Completions: 50\n")
      ;; insert habit name
  (insert (propertize habit-title 'face 'org-agenda-structure) "\n")
  ;; insert habit repeat data, next due date
  (insert (format "Repeats every %s%d days" (nth 5 habit-data) (nth 1 habit-data)) "\n")
  (insert (org-format-time-string "Next Scheduled: %A, %B %d, %Y"
                              (days-to-time (nth 0 habit-data))) "\n\n")
  ;; TODO for format-time-string, must subtract 1970 from the year before
  ;; write a function org-habit-stats--
    (org-habit-stats--insert-divider)
    (insert "Statistics" "\n\n")
    (org-habit-stats-insert-stats habit-title habit-data full-history)
    (org-habit-stats--insert-divider)
    (insert "Days Completed")
    (insert (make-string 2 ?\n))
    ;;; create calendar
    (org-habit-stats-make-calendar-buffer habit-data)
    (org-habit-stats-insert-calendar habit-data)
    (org-habit-stats--insert-divider)
    (insert "Graph")
    (insert (make-string 3 ?\n))
    ;;; create graph
    (org-habit-stats-draw-graph completed-history)
    ))

(defun org-habit-stats-format-one-stat (statname statdata)
  (concat (propertize statname 'face 'default)
          " "
          (propertize (cond ((integerp statdata) (format "%d" statdata))
                            ((floatp statdata) (format "%.3f" statdata))
                            (t statdata))
                      'face 'modus-themes-refine-green)
          "\n"))

(defun org-habit-stats-calculate-stats (habit-data full-history)
  (let ((statresults '()))
  (dolist (x org-habit-stats-stat-functions-alist)
    (let* ((statfunc (car x))
           (statname (cdr x))
           (statresult (if (fboundp statfunc) (funcall statfunc full-history habit-data))))
      (when statresult
        (push (cons statname statresult) statresults))))
    statresults))



(defun org-habit-stats-insert-stats (habit-title habit-data full-history)
  ;; insert habit stats
    (let* ((i 0)
           (statresults (org-habit-stats-calculate-stats habit-data full-history)))
      (dolist (x statresults)
        (insert (org-habit-stats-format-one-stat (car x)
                                                 (cdr x)))
        (when (and (> i 0) (= (mod i 3) 0))
          (insert "\n"))
        (setq i (1+ i)))
      (insert "\n")))


(defun org-habit-stats-insert-calendar (habit-data)
    (let ((cal-offset-for-overlay (1- (point))))
      (insert (org-habit-stats-get-calendar-contents))
      (org-habit-stats-apply-overlays (org-habit-stats-get-calendar-overlays)
                                      cal-offset-for-overlay
                                      (current-buffer)))
    (insert (make-string 2 ?\n))
  )

(defun org-habit-stats-draw-graph (history)
  (let* ((func org-habit-stats-graph-current-func)
         (func-info (cdr (assoc func org-habit-stats-graph-functions-alist)))
         (graph-title (nth 1 func-info))
         (x-name (nth 2 func-info))
         (y-name (nth 3 func-info))
         (dir (nth 4 func-info))
         (max-bars (nth 5 func-info))
         (graph-data-names (funcall func history))
         (graph-names (car graph-data-names))
         (graph-data (cdr graph-data-names))
         )
    (org-habit-stats--draw-graph
     dir
     graph-title
     graph-names
     x-name
     graph-data
     y-name
     max-bars)
    ))

(defun org-habit-stats--draw-graph (dir title namelst nametitle numlst numtitle max-bars)
  (let ((namediff (- org-habit-stats-graph-min-num-bars (length namelst)))
        (numdiff (- org-habit-stats-graph-min-num-bars (length numlst))))
    (if (> namediff 0)
        (dotimes (x namediff)
        (push "" namelst)))
    (if (> numdiff 0)
        (dotimes (x numdiff)
        (push 0 numlst)))
    (let ((chart-face-list org-habit-stats-graph-face-list))
  (org-habit-stats-chart-bar-quickie-extended
   dir
   title
   namelst
   nametitle
   numlst
   numtitle
   max-bars
   nil
   org-habit-stats-graph-current-offset
   t
   org-habit-stats-graph-width
   org-habit-stats-graph-height
   (line-number-at-pos)
   org-habit-stats-graph-left-margin
   'org-habit-stats-graph-title
   'org-habit-stats-graph-name
   'org-habit-stats-graph-label))))

(defun org-habit-stats--chart-trim-offset (seq max offset end)
  (let* ((newbeg (min offset (- (length seq) max)))
         (newend (min (+ offset max) (length seq))))
    (if (>= newbeg 0)
      (if end
          (subseq seq (- newend) (if (> newbeg 0) (- newbeg)))
        (subseq seq newbeg newend))
      seq)))


(cl-defmethod org-habit-stats-chart-trim-offset ((c chart) max offset end)
  "Trim all sequences in chart C to be MAX elements. Does nothing
if a sequence is less than MAX elements long. If END is nil, trim
offset elements, keep the next MAX elements, and trim the
remaining elements. If END is t, trimming begins at the end of
the sequence instead."
  (let ((s (oref c sequences))
        (nx (if (equal (oref c direction) 'horizontal)
                        (oref c y-axis) (oref c x-axis))))
    (dolist (x s)
      (oset x data (org-habit-stats--chart-trim-offset
                    (oref x data) max offset end))
    (oset nx items (org-habit-stats--chart-trim-offset
                    (oref nx items) max offset end)))))

;;; Graph helpers
;; (defun org-habit-stats-color-brightness (hex)
;;   "Formula from https://alienryderflex.com/hsp.html"
;;   (let ((R (substring hex 1 3))
;;         (G (substring hex 3 5))
;;         (B (substring hex 5 7))))
;;   )

(defun org-habit-stats-graph-create-faces ()
  "TODO add terminal support"
  (let ((light-bg (if (equal (frame-parameter nil 'background-mode) 'light) t nil))
        (faces ())
        newface)
    (dolist (color (if light-bg org-habit-stats-graph-colors-for-light-list
                     org-habit-stats-graph-colors-for-dark-list))
      (setq newface (make-face
                (intern (concat "org-habit-chart-" color))))
            (set-face-background newface color)
            (set-face-foreground newface "black")
            (push newface faces))
    faces))
(setq chart-face-use-pixmaps t)
;;; Calendar helpers
;; create calendar buffer, inject text at top, mark custom dates, set so curr month on the right first
(defun org-habit-stats-make-calendar-buffer (habit-data)
  ;; (interactive "P")
  ;; (with-current-buffer
  (with-current-buffer
   (get-buffer-create org-habit-stats-calendar-buffer)
  (calendar-mode)
  (let* ((date (calendar-current-date))
         (month (calendar-extract-month date))
         (year (calendar-extract-year date))
         (current-month-align-right-offset 1)
         (completed-dates (nth 4 habit-data)))
    (calendar-generate-window month year)
    (calendar-increment-month month year (- current-month-align-right-offset))
    (org-habit-stats-calendar-mark-habits habit-data)
    )
  (run-hooks 'calendar-initial-window-hook)))

(defun org-habit-stats-calendar-mark-habits (habit-data)
  (let ((completed-dates (nth 4 habit-data))
        (calendar-buffer org-habit-stats-calendar-buffer))
    (dolist (completed-day completed-dates nil)
      (let ((completed-day-gregorian (calendar-gregorian-from-absolute completed-day)))
        (when (calendar-date-is-visible-p completed-day-gregorian)
            (calendar-mark-visible-date completed-day-gregorian 'org-habit-stats-calendar-completed))))))

(defun org-habit-stats-get-calendar-contents ()
  (with-current-buffer org-habit-stats-calendar-buffer
    (buffer-string)))

(defun org-habit-stats-get-calendar-overlays ()
  (with-current-buffer org-habit-stats-calendar-buffer
    (let ((ol-list (overlay-lists)))
      (append (car ol-list) (cdr ol-list)))))

(defun org-habit-stats-apply-overlays (ol-list offset buffer)
  (dolist (ol ol-list)
     (move-overlay (copy-overlay ol)
                   (+ (overlay-start ol) offset)
                   (+ (overlay-end ol) offset)
                   buffer)))

(defun org-habit-stats-calendar-scroll-right ()
  (interactive)
  (with-current-buffer org-habit-stats-calendar-buffer
    (calendar-scroll-right)
    (org-habit-stats-calendar-mark-habits org-habit-stats-current-habit-data))
  (org-habit-stats-refresh-buffer)
  )

(defun org-habit-stats-test-1-make-buffer ()
  (interactive)
  (org-habit-stats-make-calendar-buffer (org-habit-parse-todo (point))))
(defun org-habit-stats-test-make-buffer ()
  (interactive)
  (org-habit-stats-create-habit-buffer (org-habit-parse-todo (point))))

(defun org-habit-stats-view-habit-at-point ()
  (interactive)
  (let ((habit-title (org-element-property :raw-value (org-element-at-point)))
        (habit-data (org-habit-parse-todo (point))))
    (org-habit-stats-create-habit-buffer habit-title habit-data))
  )


;; create a calender buffer with a custom name, don't open it



;; create a new mode

;; insert the calender buffer's contents into the current buffer



(provide 'org-habit-stats)
;;; org-habit-stats.el ends here
