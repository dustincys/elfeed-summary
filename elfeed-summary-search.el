;;; elfeed-summary-search.el --- Summary-based search for Elfeed entries  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; Fuzzy search across Elfeed entries using their AI-generated summaries.
;; Provides `completing-read' based interactive search.
;;
;;; Code:

(require 'elfeed)


(defun elfeed-summary--elfeed-fuzzy-search-summaries ()
  "Fuzzy search Elfeed entries based on their AI summary field."
  (interactive)
  (let ((candidates (list))
        (summary-key :summary))
    (message "Loading summaries...")
    (with-elfeed-db-visit (entry _)
      (let ((summary (elfeed-meta entry summary-key))
            (title (elfeed-entry-title entry)))
        (when (and summary (stringp summary) (not (string-empty-p summary)))
          (let* ((clean-summary (replace-regexp-in-string "\n" "" summary))
                 (display-str (format "%s -- %s"
                                      (propertize title 'face 'elfeed-search-title-face)
                                      (propertize clean-summary 'face 'font-lock-comment-face))))
            (push (cons display-str entry) candidates)))))
    (if (null candidates)
        (message "No AI summaries found.")
      (let* ((selection (completing-read "Search Summaries: " candidates))
             (entry (cdr (assoc selection candidates))))
        (when entry
          (elfeed-show-entry entry)
          (message "Opened: %s" (elfeed-entry-title entry)))))))

(provide 'elfeed-summary-search)
;;; elfeed-summary-search.el ends here
