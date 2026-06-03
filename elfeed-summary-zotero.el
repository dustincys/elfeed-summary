;;; elfeed-summary-zotero.el --- Zotero API integration for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (helm "3.8"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module provides Zotero integration via the local Zotero HTTP API.
;; Functions for fetching BibTeX strings, listing PDF attachments, and
;; selecting items via Helm.
;;
;; Requirements:
;;   - Zotero running with the "Better BibTeX" plugin
;;   - Zotero local HTTP server enabled (default port 23119)
;;
;; Usage:
;;   (require 'elfeed-summary-zotero)
;;
;;; Code:

(require 'helm)

(declare-function json-parse-string "json" (string &rest args))


(defun elfeed-summary--zotero-fetch-bibtex-string (item-key)
  "Fetch the BibTeX string for a specific Zotero ITEM-KEY."
  (let* ((url (format "http://127.0.0.1:23119/api/users/0/items/%s?format=bibtex" item-key))
         (buffer (url-retrieve-synchronously url))
         bibtex)
    (when buffer
      (with-current-buffer buffer
        (goto-char (point-min))
        ;; Skip HTTP headers (find first blank line)
        (if (re-search-forward "\r?\n\r?\n" nil t)
            (setq bibtex (string-trim (buffer-substring-no-properties (point) (point-max))))
          (setq bibtex "Error: Could not parse BibTeX response")))
      (kill-buffer buffer))
    bibtex))

(defun elfeed-summary--zotero-helm-get-pdf-paths ()
  "Fetch Zotero PDFs and return list of (TITLE . (PATH PARENT-KEY))."
  ;; Added limit=1000 to ensure we get enough items
  (let* ((url "http://127.0.0.1:23119/api/users/0/items?itemType=attachment&limit=1000")
         (url-request-extra-headers '(("Accept" . "application/json")))
         (buffer (url-retrieve-synchronously url))
         json-body attachments)

    (unless buffer
      (error "Failed to retrieve URL: %s" url))

    (with-current-buffer buffer
      (goto-char (point-min))
      (when (re-search-forward "\r?\n\r?\n" nil 'move)
        (setq json-body (buffer-substring-no-properties (point) (point-max))))
      (kill-buffer buffer))

    (let ((json-array (json-parse-string json-body :object-type 'alist)))
      (setq attachments (append json-array nil)))

    (cl-remove-if-not
     #'identity
     (mapcar (lambda (item)
               (let* ((data (alist-get 'data item))
                      (parent-key (alist-get 'parentItem data))
                      (content-type (alist-get 'contentType data))
                      (links (alist-get 'links item))
                      (enclosure (alist-get 'enclosure links)))

                 (when (and (string= content-type "application/pdf")
                            enclosure
                            parent-key) ;; Ensure we have a parent key
                   (let ((href (alist-get 'href enclosure))
                         (title (alist-get 'title enclosure)))

                     (when (and href title)
                       (when (string-prefix-p "file://" href)
                         (setq href (url-unhex-string (string-remove-prefix "file://" href))))

                       ;; RETURN format: (Title . (Path ParentKey))
                       (cons title (list href parent-key)))))))
             attachments))))

(defun elfeed-summary--zotero-helm-return-data (&optional default-input)
  "Prompt user to select a Zotero item via Helm.
Returns a cons cell (BibTeX-String . PDF-Path)."
  (interactive)
  (let ((candidates (elfeed-summary--zotero-helm-get-pdf-paths)))
    (helm :sources `((name . "Select Zotero Paper")
                     (candidates . ,candidates)
                     (action . (lambda (candidate)
                                 ;; candidate is formatted as: (Path ParentKey)
                                 (let* ((path (nth 0 candidate))
                                        (key  (nth 1 candidate))
                                        (bib  (elfeed-summary--zotero-fetch-bibtex-string key)))
                                   ;; Return the data structure
                                   (cons bib path)))))
          :input (when default-input (string-trim default-input))
          :execute-action-at-once-if-one t)))


(provide 'elfeed-summary-zotero)
;;; elfeed-summary-zotero.el ends here
