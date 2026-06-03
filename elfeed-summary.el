;;; elfeed-summary.el --- Elfeed summary & exporter  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5") (elfeed-goodies "0.9") (org "9.6"))
;; Keywords: news, paper
;; URL: https://github.com/yourname/elfeed-summary

;;; Commentary:
;; ...
;;; Code:


(defgroup elfeed-summary nil
  "Elfeed summary utilities."
  :group 'applications)

(defcustom elfeed-summary--env-file "~/.env"
  "Env file for PubMed credentials."
  :type 'file)

(defun elfeed-summary--load-env-file (&optional file)
  "Load environment variables from FILE."
  (let ((env-file
         (expand-file-name
          (or file "~/.env"))))
    (when (file-exists-p env-file)
      (with-temp-buffer
        (insert-file-contents env-file)
        (dolist (line
                 (split-string
                  (buffer-string)
                  "\n"
                  t))
          ;; skip comments
          (unless
              (or
               (string-prefix-p "#" line)
               (string-empty-p line))
            (when
                (string-match
                 "^\\([^=]+\\)=\\(.*\\)$"
                 line)
              (let ((key
                     (string-trim
                      (match-string 1 line)))
                    (value
                     (string-trim
                      (match-string 2 line))))
                ;; remove surrounding quotes
                (setq value
                      (replace-regexp-in-string
                       "\\`[\"']\\|[\"']\\'"
                       ""
                       value))
                (setenv key value)))))))))

(defun elfeed-summary-initialize ()
  (elfeed-summary--load-env-file
   elfeed-summary--env-file))

(defcustom elfeed-summary-pubmed-email
  nil
  "PubMed email address."
  :type '(choice string (const nil)))

(defcustom elfeed-summary-pubmed-api-key
  nil
  "NCBI API key."
  :type '(choice string (const nil)))

(defcustom elfeed-summary-node-fetch-script
  "/home/dustin/github/article-summarizer/src/fetch-articles.js"
  "Path to the Node.js script that accepts an input file (one URL per line)
and an output file, writing a JSON object mapping URL → summary."
  :type 'file
  :group 'elfeed-summary)

(defcustom elfeed-summary-fetch-timeout 7200
  "Timeout in seconds for the batch fetch process."
  :type 'integer
  :group 'elfeed-summary)



(require 'elfeed)
(require 'elfeed-goodies)
(require 'org)

;; Core utilities (used by all sub-modules)
(require 'elfeed-summary-utils)
(require 'elfeed-summary-pubmed)

;; Feature modules
(require 'elfeed-summary-appearance)
(require 'elfeed-summary-summarize)
(require 'elfeed-summary-export)
(require 'elfeed-summary-search)
(require 'elfeed-summary-print)
(require 'elfeed-summary-operations)
(require 'elfeed-summary-keys)

;; Optional integrations (load gracefully)
(require 'elfeed-summary-update-entry nil t)
(require 'elfeed-summary-zotero nil t)
(require 'elfeed-summary-zotra nil t)
(require 'elfeed-summary-org-protocol nil t)

(provide 'elfeed-summary)
;;; elfeed-summary.el ends here
