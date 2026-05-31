;;; elfeed-summary-appearance.el --- Custom entry display for Elfeed  -*- lexical-binding: t; -*-

;; Author: Your Name <email>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5") (elfeed-goodies "0.9"))
;; Keywords: news, paper
;; Commentary:
;; Overrides elfeed-goodies's entry display to include custom
;; metadata (summary, bib, doi, abstract, pdf) and simplified
;; HTML-to-text conversion.
;;
;; Usage:
;;   (require 'elfeed-summary-appearance)
;;   ;; It will automatically override `elfeed-goodies/show-refresh--plain'.

;;; Code:

(require 'elfeed)
(require 'elfeed-goodies)

;; ── Helpers ──────────────────────────────────────────────────────────

(defun elfeed-summary--html-to-text-simple (html)
  "Convert HTML to single-line text by stripping tags."
  (replace-regexp-in-string
   "^ *\\| *$" ""
   (replace-regexp-in-string
    "[ \t\n]+" " "
    (replace-regexp-in-string
     "<[^>]+>" "" html))))

;; ── Override the entry display function ──────────────────────────────

(defun elfeed-goodies/show-refresh--plain ()
  "Insert Content into Entry show buffer.
Show enriched metadata (title, authors, institution, summary,
bib, doi, abstract, pdf) and simplified HTML content."
  (interactive)
  (let* ((inhibit-read-only t)
         (entry elfeed-show-entry)
         (title (elfeed-entry-title entry))
         (date (seconds-to-time (elfeed-entry-date entry)))
         (link (elfeed-entry-link entry))
         (authors (elfeed-meta entry :authors))
         (institution (elfeed-meta entry :author_corresponding_institution))
         (summary (elfeed-meta entry :summary))
         (bib (elfeed-meta entry :bib))
         (doi (elfeed-meta entry :doi))
         (abstract (elfeed-meta entry :abstract))
         (pdf (elfeed-meta entry :pdf))
         (tags (elfeed-entry-tags entry))
         (content (elfeed-deref (elfeed-entry-content entry)))
         (content-type (elfeed-entry-content-type entry))
         (feed (elfeed-entry-feed entry))
         (feed-title (elfeed-feed-title feed)))
    (erase-buffer)
    (when title
      (insert (format "TITLE: %s\n\n" (propertize title 'face 'bold))))
    (when feed-title
      (insert (format "Feed: %s\n" feed-title)))
    (when authors
      (insert "Authors: ")
      (dolist (a authors)
        (insert (elfeed--show-format-author a) ", "))
      (delete-char -2)                 ; remove trailing comma
      (insert "\n"))
    (when institution
      (insert (format "Institution: %s\n" institution)))
    (when date
      (insert (format "Date: %s\n" (format-time-string "%Y-%m-%d" date))))
    (when doi
      (insert (format "DOI: %s\n" doi)))
    (when tags
      (insert (format "Tags: %s\n" (mapconcat #'symbol-name tags ", "))))
    (when link
      (insert (format "Link: %s\n" link)))
    (when summary
      (insert (format "\nSUMMARY:\n%s\n" summary)))
    (when abstract
      (insert (format "\nABSTRACT:\n%s\n" abstract)))
    (when bib
      (insert (format "\nBIBTEX:\n%s\n" bib)))
    (when pdf
      (insert (format "\nPDF:\n%s\n" pdf)))
    (if content
        (if (eq content-type 'html)
            (insert "Content:\n" (elfeed-summary--html-to-text-simple content))
          (insert "Content:\n" content))
      (insert (propertize "(empty)\n" 'face 'italic)))
    (goto-char (point-min))))

(provide 'elfeed-summary-appearance)
;;; elfeed-summary-appearance.el ends here
