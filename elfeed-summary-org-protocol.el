;;; elfeed-summary-org-protocol.el --- Org-protocol handler for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (org "9.6") (elfeed "3.5") (helm "3.8"))
;; Keywords: news, paper
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module registers an `org-protocol' handler for the custom
;; `elfeed-summary://' link type.  It uses Helm to let you select an
;; Elfeed entry by title, attaches a summary to it, indexes it
;; asynchronously (via `elfeed-summary-db'), and refreshes visible
;; entry buffers.
;;
;; Dependencies:
;;   - `elfeed-summary-db'   → `elfeed-summary-db-index-entry-async'
;;   - The custom helpers `elfeed-tag-1' / `elfeed-untag-1' must be
;;     defined somewhere (e.g., in `elfeed-summary-operations').
;;
;; Usage:
;;   1. Ensure `server-start' is called in Emacs.
;;   2. Load this module:
;;        (require 'elfeed-summary-org-protocol)
;;   3. From an external program, call:
;;        emacsclient "org-protocol://elfeed-summary?url=URL&title=TITLE&summary=SUMMARY"
;;
;;; Code:

(require 'org-protocol)
(require 'helm)
(require 'elfeed-db)            ;; for elfeed-db-entries hash table
(require 'elfeed-show)          ;; for elfeed-show-refresh
(require 'elfeed-summary-utils)


;; ─── declare function ──────────────────────────────────────────────────────;
(declare-function elfeed-summary-db-index-entry-async
                  "elfeed-summary-operations"
                  (entry))

;; ── Register the protocol ────────────────────────────────────────────
(eval-after-load 'org-protocol
  '(add-to-list 'org-protocol-protocol-alist
                '("elfeed-summary"
                  :protocol "elfeed-summary"
                  :function elfeed-summary--capture)))

;; ── Main capture handler ─────────────────────────────────────────────
(defun elfeed-summary--capture (info)
  "Handle `org-protocol://elfeed-summary' requests.
INFO is a plist containing keys :url, :title, :summary
(as passed by `org-protocol')."
  (let* ((url     (plist-get info :url))
         (title   (plist-get info :title))
         (title   (replace-regexp-in-string "|.*$" "" title))
         (title   (replace-regexp-in-string " - ScienceDirect$" "" title))
         (summary (plist-get info :summary))
         (entry   (elfeed-summary--select-entry title)))
    ;; If Emacs was launched just for this client request, close its frame.
    (when (frame-parameter nil 'client)
      (delete-frame))
    (message "org-protocol://elfeed-summary handling: %s" title)
    (when entry
      (elfeed-summary--save-summary entry summary)
      (message "Saved summary into entry: %s" (elfeed-entry-title entry))
      (when summary
        (message "Begin indexing %s..." (elfeed-entry-title entry))
        (elfeed-summary-db-index-entry-async entry)
        (message "Indexing %s..." (elfeed-entry-title entry)))
      ;; Update the search view and the show buffer if they are visible.
      (when (eq major-mode 'elfeed-search-mode)
        (elfeed-search-update-line))
      (let ((show-buffer (get-buffer "*elfeed-entry*")))
        (when show-buffer
          (with-current-buffer show-buffer
            (when (and (boundp 'elfeed-show-entry)
                       (equal elfeed-show-entry entry))
              (elfeed-show-refresh)))))
      (elfeed-db-save))
    nil))

(provide 'elfeed-summary-org-protocol)
;; Local Variables:
;; comment-column: 0
;; End:
;;; elfeed-summary-org-protocol.el ends here
