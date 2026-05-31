;;; elfeed-summary-utils.el --- Common utility functions for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news, tools
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module collects helper functions used throughout the
;; `elfeed-summary' package.  They cover:
;;   - String cleaning and HTML stripping
;;   - Safe metadata access
;;   - Tag checking
;;   - Date formatting
;;   - Temporary file helpers
;;
;; Usage:
;;   (require 'elfeed-summary-utils)
;;
;;; Code:

(require 'elfeed)

;; ── String utilities ─────────────────────────────────────────────────

(defun elfeed-summary--html-to-text (html)
  "Strip HTML tags from HTML and collapse whitespace."
  (replace-regexp-in-string
   "^ *\\| *$" ""
   (replace-regexp-in-string
    "[ \t\n]+" " "
    (replace-regexp-in-string
     "<[^>]+>" "" html))))

(defun elfeed-summary--clean-title (title)
  "Remove common noise from a paper/article TITLE.
For instance, strips everything after a '|' and removes
' - ScienceDirect' suffix."
  (let ((clean title))
    (setq clean (replace-regexp-in-string "|.*$" "" clean))
    (replace-regexp-in-string " - ScienceDirect$" "" clean)))

;; ── Metadata helpers ─────────────────────────────────────────────────

(defun elfeed-summary--meta (entry key &optional default)
  "Safely read Elfeed meta KEY from ENTRY.
Return DEFAULT if the key is missing (default nil)."
  (if entry
      (elfeed-meta entry key)
    default))

(defun elfeed-summary--meta-put (entry key value)
  "Set meta KEY to VALUE for ENTRY (like `elfeed-meta--put')."
  (elfeed-meta--put entry key value))

(defun elfeed-summary--get-summary (entry)
  "Return the stored summary of ENTRY, or an empty string."
  (or (elfeed-summary--meta entry :summary) ""))

;; ── Tag utilities ────────────────────────────────────────────────────

(defun elfeed-summary--has-tag (entry tag)
  "Return t if ENTRY has TAG."
  (member tag (elfeed-entry-tags entry)))

(defun elfeed-summary--add-tag (entry tag)
  "Add TAG to ENTRY (no database save)."
  (elfeed-entry-set-tags
   entry (cl-pushnew tag (elfeed-entry-tags entry) :test #'equal)))

(defun elfeed-summary--remove-tag (entry tag)
  "Remove TAG from ENTRY (no database save)."
  (elfeed-entry-set-tags
   entry (remove tag (elfeed-entry-tags entry))))

;; ── Date / time ──────────────────────────────────────────────────────

(defun elfeed-summary--format-date (seconds)
  "Format SECONDS (a time value) as YYYY-MM-DD."
  (format-time-string "%Y-%m-%d" (seconds-to-time seconds)))

;; ── File utilities ───────────────────────────────────────────────────

(defun elfeed-summary--make-temp-file (prefix &optional suffix)
  "Create a temporary file with PREFIX and optional SUFFIX.
Wrapper for `make-temp-file'."
  (make-temp-file prefix nil suffix))

(defun elfeed-summary--delete-file-silently (file)
  "Delete FILE, ignoring errors."
  (ignore-errors (delete-file file)))

;; ── Misc ─────────────────────────────────────────────────────────────

(defun elfeed-summary--message (format-string &rest args)
  "Like `message', but prefixed with [elfeed-summary]."
  (apply #'message (concat "[elfeed-summary] " format-string) args))

(provide 'elfeed-summary-utils)
;;; elfeed-summary-utils.el ends here
