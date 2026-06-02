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


;; elfeed utilities ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun elfeed-summary--parse-json-result (json-data)
  "将 JSON 数据转换为 URL 到内容的哈希表"
  (let ((hash (make-hash-table :test 'equal)))
    (cl-loop for item across json-data do
             (let* ((url (alist-get 'url item))
                    (raw-summary (alist-get 'summary item))
                    (summary (if (or (null raw-summary)
                                     (string-empty-p raw-summary))
                                 ""
                               raw-summary)))
               (when url
                 (puthash url summary hash))))
    hash))



;; elfeed entry operation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun elfeed-summary--search-entries ()
  "Return all visible entries in current elfeed-search buffer."
  (let (entries)
    (with-current-buffer "*elfeed-search*"
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (let ((entry
                 (elfeed-search-selected
                  :ignore-region)))
            (when entry
              (push entry entries)))
          (forward-line 1))))
    (cl-remove-duplicates
     (nreverse entries))))


(defun elfeed-summary--entry-to-string (entry)
  "Format ENTRY into a human-readable string for Helm."
  (let ((title (elfeed-entry-title entry))
        (feed  (elfeed-feed-title (elfeed-entry-feed entry))))
    (format "[%s] %s" feed title)))

(defun elfeed-summary--select-entry (&optional default-input)
  "Select an Elfeed entry using Helm.
DEFAULT-INPUT is a string used to pre‑filter the candidates.
Returns the chosen entry or nil if aborted."
  (helm :sources
        (list
         (helm-build-sync-source "Elfeed entries"
           :candidates (mapcar
                        (lambda (e)
                          (cons (elfeed-summary--entry-to-string e) e))
                        (hash-table-values elfeed-db-entries))
           :fuzzy-match t
           :action 'identity))
        :buffer "*helm elfeed*"
        :input (when default-input (string-trim default-input))
        :execute-action-at-once-if-one t))


(defun elfeed-summary--get-current-entry ()
  "Return the Elfeed entry for the current buffer."
  (cond
   ;; Entry buffer
   ((derived-mode-p 'elfeed-show-mode)
    (bound-and-true-p elfeed-show-entry))
   ;; Search buffer
   ((derived-mode-p 'elfeed-search-mode)
    (or (elfeed-search-selected t) elfeed-show-entry))
   (t
    (error "Not in an Elfeed buffer"))))


(defun elfeed-summary--elfeed-save-summary (entry text)
  "Save TEXT as summary for ENTRY and update the modification timestamp."
  (elfeed-tag-1 entry 'summarized)
  (elfeed-untag-1 entry 'to-summarize)
  (elfeed-meta--put entry :summary text)
  (elfeed-meta--put entry :summary-modified-at (float-time)))


;; ── Tagging helpers (moved here from `elfeed-summary-org-protocol') ──

(defun elfeed-summary--elfeed-tag-1 (entry tag)
  "Add TAG to ENTRY without triggering a full DB save."
  (elfeed-entry-set-tags
   entry (cl-pushnew tag (elfeed-entry-tags entry) :test #'equal)))

(defun elfeed-summary--elfeed-untag-1 (entry tag)
  "Remove TAG from ENTRY without triggering a full DB save."
  (elfeed-entry-set-tags
   entry (remove tag (elfeed-entry-tags entry))))


;; string operation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun elfeed-summary--html-to-text-simple (html)
  "Convert HTML to single-line text by stripping tags."
  (replace-regexp-in-string
   "^ *\\| *$" ""
   (replace-regexp-in-string
    "[ \t\n]+" " "
    (replace-regexp-in-string
     "<[^>]+>" "" html))))


(defun elfeed-summary--extract-biorxiv-doi (url)
  "Extract clean bioRxiv DOI from URL."
  (when (and url
             (string-match
              "10\\.[0-9]+/[A-Za-z0-9._;()/:-]+"
              url))
    (let ((doi (match-string 0 url)))
      ;; remove trailing v1/v2/v3...
      (replace-regexp-in-string
       "v[0-9]+$"
       ""
       doi))))


(defun elfeed-summary--science-url-to-doi (url)
  (when
      (string-match
       "science\\.org/doi/\\(?:full/\\|abs/\\)?\\([^?]+\\)"
       url)
    (match-string 1 url)))


;; url operations ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun elfeed-summary--http-get-json (url)
  (with-current-buffer
      (url-retrieve-synchronously url t t 30)
    (goto-char (point-min))
    (re-search-forward "^$")
    (forward-char)
    (json-parse-buffer
     :object-type 'alist
     :array-type 'list)))

(defun elfeed-summary--http-get-xml (url)
  (with-current-buffer
      (url-retrieve-synchronously url t t 30)
    (goto-char (point-min))
    (re-search-forward "^$")
    (forward-char)
    (libxml-parse-xml-region
     (point)
     (point-max))))

(defun elfeed-summary--xml-get-children (node tag)
  (seq-filter
   (lambda (x)
     (and (listp x)
          (eq (car x) tag)))
   (xml-node-children node)))

(defun elfeed-summary--xml-first-child (node tag)
  (car
   (elfeed-summary--xml-get-children node tag)))

(defun elfeed-summary--xml-node-text (node)
  (when node
    (string-trim
     (mapconcat
      (lambda (x)
        (cond
         ((stringp x) x)
         ((listp x)
          (elfeed-summary--xml-node-text x))
         (t "")))
      (xml-node-children node)
      ""))))

(defun elfeed-summary--xml-path (node &rest tags)
  (seq-reduce
   (lambda (n tag)
     (when n
       (elfeed-summary--xml-first-child n tag)))
   tags
   node))

;; time operations ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun elfeed-summary--parse-rdf-date (date-str)
  "Try to parse DATE-STR as ISO 8601 or fallback.
Return a time value (seconds since epoch) or nil."
  (when (stringp date-str)
    (condition-case nil
        (if (fboundp 'iso8601-parse-string)
            ;; Emacs 26+
            (let ((time (iso8601-parse-string date-str)))
              (encode-time (decoded-time-add time (make-decoded-time))))
          ;; Fallback: try parse-time-string
          (let ((parsed (parse-time-string date-str)))
            (when (car parsed) ; at least year
              (encode-time parsed))))
      (error nil))))



(provide 'elfeed-summary-utils)
;;; elfeed-summary-utils.el ends here

;; Local Variables:
;; comment-column: 0
;; End:
