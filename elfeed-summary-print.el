;;; elfeed-summary-print.el --- Terminal output for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module provides functions to print Elfeed entry metadata
;; for external tool consumption (e.g., openclaw skills).
;; Supports output modes: all, summary, bib.
;;
;;; Code:

(require 'elfeed)
(require 'elfeed-summary-utils)


;; ── Single entry printing ──────────────────────────────────────────────

(defun elfeed-summary--print-ID-summary (entry-id &optional output-mode)
  (let ((e (elfeed-db-get-entry entry-id)))
    (if (not e)
        (message "Entry ID %s 不存在" entry-id)
      (let ((title (elfeed-entry-title e))
            (link (elfeed-entry-link e))
            (summary (elfeed-meta e :summary))
            (abstract (elfeed-meta e :abstract))
            (date (format-time-string "%Y-%m-%d"
                                      (seconds-to-time (elfeed-entry-date e))))
            (authors (elfeed-meta e :authors))
            (bib (elfeed-meta e :bib))
            (bibkey (elfeed-meta e :bibkey))
            (doi (elfeed-meta e :doi))
            (journal (elfeed-summary--get-journal e))
            (score (if (fboundp 'elfeed-score-scoring-get-score-from-entry)
                       (elfeed-score-scoring-get-score-from-entry e)
                     0))
            )
        (pcase output-mode
          ("bib"
           (when bib
             (format "%s\n\n" bib)))
          ("summary"
           (when summary
             (format "Title: %s\nSummary: %s\nAbstract: %s\nbibkey: %s\nScore: %s\n\n" title summary abstract bibkey score))
           )
          ("all"
           (format "Title: %s\nJournal: %s\nDate: [%s]\nURL: %s\nSummary: %s\nAbstract: %s\nBibTeX: %s\ndoi: %s\nAuthors: %s\nScore: %s\n\n"
                   title
                   journal
                   date
                   link
                   (if (and summary (not (string-empty-p summary)))
                       (replace-regexp-in-string "\n" " " summary)
                     "No summary available")
                   abstract
                   bib
                   doi
                   authors
                   score
                   ))
          (_
           (format "Unknown output-mode: %s\n" output-mode)))
        ))))

(defun elfeed-summary--print-multiple-ID-summary (id-list output-mode)
  (let ((output-mode (or output-mode 'all)))
    (mapconcat (lambda (id) (elfeed-summary--print-ID-summary id output-mode))
               id-list
               "\n")))


(defun elfeed-summary--get-journal (entry)
  (or
   (elfeed-feed-title (elfeed-entry-feed entry))
   (elfeed-feed-url (elfeed-entry-feed entry))
   (elfeed-feed-id (elfeed-entry-feed entry))
   (when (elfeed-entry-tags entry)
     (mapconcat #'symbol-name (elfeed-entry-tags entry) ", "))))


(defun elfeed-summary--search-print-summary (search-keyword output-mode &optional top-n elfeed-filter)
  (let* ((output-mode (or output-mode 'all))
         (candidates '())
         (top-n (or top-n 10))
         (filter (when (and elfeed-filter (not (string-empty-p elfeed-filter)))
                   (elfeed-search-parse-filter elfeed-filter)))
         (filter-fn (when filter
                      (elfeed-search-compile-filter filter))))

    (with-elfeed-db-visit (entry _)
      (let* ((summary (elfeed-meta entry :summary))
             (abstract (elfeed-meta entry :abstract))
             (title (elfeed-entry-title entry))
             (link (elfeed-entry-link entry))
             (authors (elfeed-meta entry :authors))
             (bib (elfeed-meta entry :bib))
             (bibkey (elfeed-meta entry :bibkey))
             (doi (elfeed-meta entry :doi))
             (entry-time (seconds-to-time (elfeed-entry-date entry)))
             (date (format-time-string "%Y-%m-%d" entry-time))
             (journal (elfeed-summary--get-journal entry))
             (score (if (fboundp 'elfeed-score-scoring-get-score-from-entry)
                        (elfeed-score-scoring-get-score-from-entry entry)
                      0)))
        (when (and
               (or (null filter-fn)
                   (funcall filter-fn
                            entry
                            (elfeed-entry-feed entry)
                            0))
               (or (null search-keyword)
                   (string-empty-p search-keyword)
                   (string-match-p (regexp-quote search-keyword)
                                   (concat (or title "") " " (or summary "") " " (or abstract "")))))
          (push (list title date link summary journal score abstract bib doi authors bibkey)
                candidates))))
    (setq candidates
          (seq-take
           (sort candidates
                 (lambda (a b) (> (nth 5 a) (nth 5 b))))
           top-n))
    (with-output-to-string
      (if (null candidates)
          (princ "No matching summaries found.\n")
        (dolist (cand candidates)
          (let ((title (nth 0 cand))
                (date (nth 1 cand))
                (link (nth 2 cand))
                (summary (nth 3 cand))
                (journal (nth 4 cand))
                (score (nth 5 cand))
                (abstract (nth 6 cand))
                (bib (nth 7 cand))
                (doi (nth 8 cand))
                (authors (nth 9 cand))
                (bibkey (nth 10 cand)))
            (pcase output-mode
              ("bib"
               (when bib
                 (princ (format "%s\n\n" bib))))
              ("summary"
               (when summary
                 (princ (format "Title: %s\nSummary: %s\nAbstract: %s\nbibkey: %s\nScore: %s\n\n" title summary abstract bibkey score)))
               )
              ("all"
               (princ
                (format
                 "Title: %s\nDate: [%s]\nJournal: %s\nURL: %s\nSummary: %s\nAbstract: %s\nBibTeX: %s\ndoi: %s\nAuthors: %s\nScore: %s\n\n"
                 title
                 date
                 (or journal "Unknown")
                 link
                 (if (and summary (not (string-empty-p summary)))
                     (replace-regexp-in-string "\n" " " summary)
                   "No summary available")
                 abstract
                 bib
                 doi
                 authors
                 score)))
              (_
               (princ (format "Unknown output-mode: %s\n" output-mode))))
            ))))))

(provide 'elfeed-summary-print)
;;; elfeed-summary-print.el ends here
