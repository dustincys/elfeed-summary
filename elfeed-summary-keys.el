;;; elfeed-summary-keys.el --- Keybindings for elfeed-summary  -*- lexical-binding: t; -*-

;; Author: Yanshuo Chu <yanshuochu@qq.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (elfeed "3.5"))
;; Keywords: news
;; URL: https://github.com/dustincys/elfeed-summary

;;; Commentary:
;;
;; This module defines the keybindings for elfeed-summary commands.
;; Bindings are attached to `elfeed-search-mode-map' and
;; `elfeed-show-mode-map'.
;;
;; Usage:
;;   (require 'elfeed-summary-keys)
;;
;;; Code:

(require 'elfeed)

(declare-function elfeed-summary--elfeed-fuzzy-search-summaries "elfeed-summary-search")
(declare-function elfeed-summary--export-search-to-pdf "elfeed-summary-export")
(declare-function elfeed-summary--export-search-to-tex "elfeed-summary-export")
(declare-function elfeed-summary--update-entry-info "elfeed-summary-update-entry")
(declare-function elfeed-summary-fetch-batch-articles "elfeed-summary-summarize")
(declare-function elfeed-summary--zotra-integrate-entry-from-zotero "elfeed-summary-zotra")
(declare-function elfeed-summary--search-entries "elfeed-summary-utils")


(defvar elfeed-summary-keymap-prefix nil
  "Prefix key for elfeed-summary commands.
Set this to a key sequence before loading to customize bindings.")

;; ── Search mode bindings ───────────────────────────────────────────────

(defvar elfeed-summary-search-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s") #'elfeed-summary--elfeed-fuzzy-search-summaries)
    (define-key map (kbd "e") #'elfeed-summary--export-search-to-pdf)
    (define-key map (kbd "E") #'elfeed-summary--export-search-to-tex)
    (define-key map (kbd "u") #'elfeed-summary--update-entry-info)
    (define-key map (kbd "A") #'elfeed-summary-fetch-batch-articles)
    (define-key map (kbd "z") #'elfeed-summary--zotra-integrate-entry-from-zotero)
    map)
  "Keymap for elfeed-summary commands in `elfeed-search-mode'.")

;; ── Show mode bindings ─────────────────────────────────────────────────

(defvar elfeed-summary-show-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "u") #'elfeed-summary--update-entry-info)
    (define-key map (kbd "A") #'elfeed-summary-fetch-batch-articles)
    (define-key map (kbd "z") #'elfeed-summary--zotra-integrate-entry-from-zotero)
    map)
  "Keymap for elfeed-summary commands in `elfeed-show-mode'.")

;; ── Minor mode for enabling bindings ───────────────────────────────────

;;;###autoload
(define-minor-mode elfeed-summary-mode
  "Minor mode for elfeed-summary keybindings.
When enabled, adds summary-related commands to Elfeed buffers."
  :global t
  :lighter " ES"
  (if elfeed-summary-mode
      (progn
        (add-hook 'elfeed-search-mode-hook
                  (lambda () (set-keymap-parent elfeed-summary-search-mode-map
                                           (current-local-map))))
        (add-hook 'elfeed-show-mode-hook
                  (lambda () (set-keymap-parent elfeed-summary-show-mode-map
                                           (current-local-map)))))
    (remove-hook 'elfeed-search-mode-hook
                 (lambda () (set-keymap-parent elfeed-summary-search-mode-map
                                         (current-local-map))))
    (remove-hook 'elfeed-show-mode-hook
                 (lambda () (set-keymap-parent elfeed-summary-show-mode-map
                                         (current-local-map))))))


(provide 'elfeed-summary-keys)
;;; elfeed-summary-keys.el ends here
