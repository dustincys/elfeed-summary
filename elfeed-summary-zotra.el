;;; elfeed-summary-zotra.el --- Zotra integration for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module integrates Zotra (Zotero Reference Aggregator) with
;; Elfeed entries.  It provides functions to:
;;   - Create BibTeX entries via Zotra
;;   - Link Zotero PDF/BibTeX to Elfeed entries
;;   - Write BibTeX for the current entry (hook for zotra)
;;
;; Usage:
;;   (require 'elfeed-summary-zotra)
;;
;;; Code:

(require 'elfeed)
(require 'elfeed-summary-utils)

(declare-function zotra-add-entry "zotra" (url))
(declare-function zotra-after-get-bibtex-entry-hook "zotra")
(declare-function elfeed-summary--zotero-helm-return-data "elfeed-summary-zotero" (&optional default-input))
(declare-function bibtex-completion-bibliography "bibtex-completion")


(defvar zotra-after-get-bibtex-entry-hook nil
  "Hook run after Zotra fetches a BibTeX entry.")


(defun elfeed-summary--write-bibtex-for-current-entry ()
  "Write BibTeX for the current Elfeed entry.
Intended for use as a hook in `zotra-after-get-bibtex-entry-hook'."
  (when (bound-and-true-p my-feed--current-elfeed-entry)
    (let ((entry my-feed--current-elfeed-entry)
          (bibtex-str (buffer-string)))
      (when bibtex-str
        (elfeed-meta--put entry :bib bibtex-str)
        (elfeed-summary--elfeed-tag-1 entry 'bib)
        (message "BibTeX saved for: %s" (elfeed-entry-title entry))))))


(defun elfeed-summary--zotra-integrate-entry (entry)
  "Create BibTeX, download PDF, update BibTeX item, and attach metadata to Elfeed ENTRY.
This is the main entry point called from `elfeed-summary-operations'."
  (interactive)
  (if (fboundp 'zotra-add-entry)
      (let* ((my-feed--current-elfeed-entry entry)
             (zotra-after-get-bibtex-entry-hook
              (append zotra-after-get-bibtex-entry-hook
                      '(elfeed-summary--write-bibtex-for-current-entry))))
        ;; call ZotRA → triggers hook
        (zotra-add-entry (elfeed-entry-link entry)))
    (message "Zotra not installed; skipping integration for %s"
             (elfeed-entry-title entry))))


(defun elfeed-summary--zotra-integrate-entry-from-zotero (entry)
  "Link Zotero PDF/BibTeX to Elfeed Entry.
Renames PDF based on sanitized Elfeed ID."
  (interactive (list (or elfeed-show-entry (elfeed-search-selected-entry))))
  (unless entry (error "No Elfeed entry selected"))

  (let* ((title (elfeed-entry-title entry))
         (clean-title (replace-regexp-in-string "|.*$" "" title)) ;; remove suffix
         (clean-title (replace-regexp-in-string " - ScienceDirect$" "" clean-title))
         (selection (if (fboundp 'elfeed-summary--zotero-helm-return-data)
                        (elfeed-summary--zotero-helm-return-data clean-title)
                      (error "Zotero integration not available"))))

    (if (not selection)
        (message "Integration cancelled.")

      (let* ((bibtex-str (car selection))
             (source-pdf (cdr selection))
             (elfeed-id (elfeed-entry-id entry))

             ;; Extract BibTeX Key
             (bib-key (if (string-match "@[^\\{]+\{\\([^,]+\\)," bibtex-str)
                          (match-string 1 bibtex-str)
                        (error "No BibTeX Key found")))

             (bib-file (if (listp bibtex-completion-bibliography)
                           (car bibtex-completion-bibliography)
                         bibtex-completion-bibliography)))

        (with-temp-buffer
          (insert "\n" bibtex-str "\n")
          (append-to-file (point-min) (point-max) bib-file))

        ;; Update Elfeed Metadata
        (when bibtex-str
          (elfeed-meta--put entry :bibkey bib-key)
          (elfeed-meta--put entry :bib bibtex-str)
          (elfeed-summary--elfeed-tag-1 entry 'bib))

        (when source-pdf
          (elfeed-meta--put entry :pdf source-pdf)
          (elfeed-summary--elfeed-tag-1 entry 'pdf))

        ;; Refresh UI
        (when (eq major-mode 'elfeed-search-mode)
          (elfeed-search-update-line))

        (let ((show-buffer (get-buffer "*elfeed-entry*")))
          (when show-buffer
            (with-current-buffer show-buffer
              (when (and (boundp 'elfeed-show-entry)
                         (equal elfeed-show-entry entry))
                (elfeed-show-refresh)))))

        (elfeed-db-save)
        (message "Linked! File: %s" source-pdf)))))


(provide 'elfeed-summary-zotra)
;;; elfeed-summary-zotra.el ends here
