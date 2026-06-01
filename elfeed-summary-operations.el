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
(require 'elfeed-summary-utils)




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



(provide 'elfeed-summary-operations)
;;; elfeed-summary-operations.el ends here
