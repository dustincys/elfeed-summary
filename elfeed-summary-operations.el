;;; elfeed-summary-operations.el --- Cross-module operations for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module provides cross-cutting operations used by multiple
;; elfeed-summary sub-modules:
;;   - Zotra integration (delegates to zotra when available)
;;   - Async DB indexing for summary full-text search
;;
;;; Code:

(require 'elfeed)
(require 'json)
(require 'elfeed-summary-utils)


;; ── Zotra integration ──────────────────────────────────────────────────

(declare-function elfeed-summary--zotra-integrate-entry
              "elfeed-summary-zotra"
              (entry))


;; ── Async summary indexing ─────────────────────────────────────────────

(defvar elfeed-summary--index-hash (make-hash-table :test 'equal)
  "Hash table mapping entry IDs to their summary text for fast lookup.")

(defun elfeed-summary-db-index-entry-async (entry)
  "Index ENTRY's summary asynchronously for full-text search.
Stores the summary text in `elfeed-summary--index-hash' keyed by
entry ID, without blocking the UI."
  (let ((entry-id (elfeed-entry-id entry))
        (summary (elfeed-meta entry :summary)))
    (when (and entry-id summary (not (string-empty-p summary)))
      (puthash entry-id summary elfeed-summary--index-hash)
      (message "Indexed summary for: %s" (elfeed-entry-title entry)))))

(defun elfeed-summary-db-search-summaries (query)
  "Search indexed summaries for QUERY string.
Returns a list of (entry-id . summary) pairs."
  (let ((results '()))
    (maphash (lambda (id summary)
               (when (string-match-p (regexp-quote query) summary)
                 (push (cons id summary) results)))
             elfeed-summary--index-hash)
    results))


(provide 'elfeed-summary-operations)
;;; elfeed-summary-operations.el ends here
