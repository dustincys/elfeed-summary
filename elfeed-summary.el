;;; elfeed-summary.el --- Elfeed summary & exporter  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5") (elfeed-goodies "0.9") (org "9.6"))
;; Keywords: news, paper
;; URL: https://github.com/yourname/elfeed-summary

;;; Commentary:
;; ...
;;; Code:

(require 'elfeed)
(require 'elfeed-goodies)
(require 'org)

(require 'elfeed-summary-appearance)
(require 'elfeed-summary-summarize)
(require 'elfeed-summary-export)
(require 'elfeed-summary-operations)
(require 'elfeed-summary-keys)


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



(provide 'elfeed-summary)
;;; elfeed-summary.el ends here
