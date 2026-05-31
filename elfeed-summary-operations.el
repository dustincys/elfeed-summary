;;; elfeed-summary-operations.el --- Batch fetch & update summaries for Elfeed  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module provides batch operations for Elfeed entries, mainly
;; `elfeed-summary-fetch-batch-articles' which:
;;   1. Collects URLs from a list of entries.
;;   2. Calls an external Node.js script to fetch/analyse the content.
;;   3. Parses the returned JSON and saves summaries to each entry.
;;   4. Optionally indexes entries and refreshes the Elfeed UI.
;;
;; Additional helpers (tagging, zotra integration, JSON parsing) are
;; also defined here or declared with `declare-function' if placed
;; elsewhere.
;;
;;; Code:

(require 'elfeed)
(require 'json)

;; ── Customisation ────────────────────────────────────────────────────

(defcustom elfeed-summary-node-fetch-script
  "/home/dustin/github/article-summarizer/src/fetch-articles.js"
  "Path to the Node.js script that accepts an input file (one URL per line)
and an output file, writing a JSON object mapping URL → summary."
  :type 'file
  :group 'elfeed-summary)

(defcustom elfeed-summary-fetch-timeout 7200
  "Timeout in seconds for the batch fetch process."
  :type 'integer
  :group 'elfeed-summary)

;; ── Tagging helpers (moved here from `elfeed-summary-org-protocol') ──

(defun elfeed-tag-1 (entry tag)
  "Add TAG to ENTRY without triggering a full DB save."
  (elfeed-entry-set-tags
   entry (cl-pushnew tag (elfeed-entry-tags entry) :test #'equal)))

(defun elfeed-untag-1 (entry tag)
  "Remove TAG from ENTRY without triggering a full DB save."
  (elfeed-entry-set-tags
   entry (remove tag (elfeed-entry-tags entry))))

;; ── Saving summaries ─────────────────────────────────────────────────

(defun elfeed-summary-save-summary (entry text)
  "Save TEXT as the summary for ENTRY.
Tags the entry as `summarized' and removes the `to-summarize' tag.
Records the summary text and the modification time in entry meta."
  (elfeed-tag-1 entry 'summarized)
  (elfeed-untag-1 entry 'to-summarize)
  (elfeed-meta--put entry :summary text)
  (elfeed-meta--put entry :summary-modified-at (float-time)))

;; ── JSON result parsing (stub – replace with your actual implementation) ──

(defun elfeed-summary--parse-json-result (json-data)
  "Parse the JSON data returned by the fetch script.
JSON-DATA is expected to be an alist or hash-table mapping URL → summary.
Return an equal-able hash table mapping URL to summary string."
  (let ((ht (make-hash-table :test 'equal)))
    (if (hash-table-p json-data)
        ;; Already a hash table
        (maphash (lambda (url summary) (puthash url summary ht)) json-data)
      ;; Assume alist
      (dolist (pair json-data)
        (puthash (car pair) (cdr pair) ht)))
    ht))

;; ── Zotra integration (stub – replace with your actual implementation) ──

(defun elfeed-summary--zotra-integrate-entry (entry)
  "Integrate ENTRY with Zotra (placeholder)."
  ;; Replace this body with your actual `my-feed/zotra-integrate-entry'.
  (message "Zotra integration for %s (currently noop)"
           (elfeed-entry-title entry)))

;; ── Async indexing (declared here, defined in `elfeed-summary-db') ──

(declare-function elfeed-summary-db-index-entry-async
                  "elfeed-summary-db"
                  (entry))

;; ── Batch fetch main function ────────────────────────────────────────

(defun elfeed-summary-fetch-batch-articles (entries)
  "Batch fetch summaries for ENTRIES using an external Node.js script.
ENTRIES is a list of Elfeed entry objects.

The script (see `elfeed-summary-node-fetch-script') is called with two
temporary files: one containing a URL per line, the other to receive a
JSON mapping of URL → summary.

After the process finishes, each entry is tagged, its summary is saved,
zotra integration is attempted, and it is queued for async indexing."
  (let* ((temp-in-file (make-temp-file "elfeed-urls-"))
         (temp-out-file (make-temp-file "elfeed-results-"))
         (command (format "node %s %s %s"
                          elfeed-summary-node-fetch-script
                          temp-in-file
                          temp-out-file))
         (proc (start-process-shell-command "elfeed-fetch-batch" nil command)))
    (message "AI summarizing...")
    (message "Input URLs file: %s" temp-in-file)
    (message "Output file: %s" temp-out-file)
    ;; Write URLs to the input file
    (with-temp-file temp-in-file
      (insert (mapconcat #'elfeed-entry-link entries "\n")))
    ;; Store data on the process plist for later use
    (set-process-plist proc
                       (list 'temp-in-file temp-in-file
                             'temp-out-file temp-out-file
                             'entries entries))
    ;; Process sentinel
    (set-process-sentinel
     proc
     (lambda (process event)
       (let ((temp-in-file (process-get process 'temp-in-file))
             (temp-out-file (process-get process 'temp-out-file))
             (entries (process-get process 'entries)))
         (message "Fetch process sentinel: %s" event)
         (when (eq (process-status process) 'exit)
           (ignore-errors (delete-file temp-in-file))
           (if (zerop (process-exit-status process))
               (condition-case err
                   (let* ((json-data (json-read-file temp-out-file))
                          (result-dict (elfeed-summary--parse-json-result json-data)))
                     (dolist (entry entries)
                       (let* ((url (elfeed-entry-link entry))
                              (summary (gethash url result-dict)))
                         (if (and summary (not (string-empty-p summary)))
                             (elfeed-summary-save-summary entry summary)
                           (progn
                             (elfeed-tag-1 entry 'NO-CONTEXT)
                             (elfeed-untag-1 entry 'to-summarize)))
                         (condition-case zot-err
                             (elfeed-summary--zotra-integrate-entry entry)
                           (error (message "ZOTRA failed for %s: %s" url zot-err)))
                         (when summary
                           (message "Begin indexing %s..." (elfeed-entry-title entry))
                           (elfeed-summary-db-index-entry-async entry)
                           (message "Indexing %s..." (elfeed-entry-title entry)))))
                     (ignore-errors (delete-file temp-out-file))
                     (message "Batch fetch done!")
                     (elfeed-db-save)
                     ;; Refresh UI
                     (when (eq major-mode 'elfeed-search-mode)
                       (elfeed-search-update-line))
                     (let ((show-buffer (get-buffer "*elfeed-entry*")))
                       (when show-buffer
                         (with-current-buffer show-buffer
                           (when (and (boundp 'elfeed-show-entry)
                                      (equal elfeed-show-entry entry))
                             (elfeed-show-refresh))))))
                 (error (message "Update summary failed: %s" err)))
             (progn
               (ignore-errors (delete-file temp-out-file))
               (message "Node.js failed, exit code: %d"
                        (process-exit-status process))))))))
    ;; Set a timeout to kill the process if it hangs
    (let ((proc proc)
          (temp-in-file temp-in-file)
          (temp-out-file temp-out-file))
      (run-at-time elfeed-summary-fetch-timeout nil
                   (lambda ()
                     (when (process-live-p proc)
                       (delete-process proc)
                       (ignore-errors (delete-file temp-in-file))
                       (ignore-errors (delete-file temp-out-file))
                       (message "Batch fetch timed out after %d seconds"
                                elfeed-summary-fetch-timeout)))))))

(provide 'elfeed-summary-operations)
;;; elfeed-summary-operations.el ends here
