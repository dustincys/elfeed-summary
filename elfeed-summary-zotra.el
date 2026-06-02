(defun my-feed/zotra-integrate-entry (elfeed-entry)
  "Create bibtex, download PDF, update bibtex item, and attach metadata to Elfeed ENTRY."
  (interactive)
  (let* ((my-feed--current-elfeed-entry elfeed-entry)
         (zotra-after-get-bibtex-entry-hook
          (append zotra-after-get-bibtex-entry-hook
                  '(my-feed/write-bibtex-for-current-entry))))
    ;; call ZotRA → triggers hook
    (zotra-add-entry (elfeed-entry-link elfeed-entry))))


(defun my-feed/zotra-integrate-entry-from-zotero (entry)
  "Link Zotero PDF/BibTeX to Elfeed Entry.
   Renames PDF based on sanitized Elfeed ID."
  (interactive (list (or elfeed-show-entry (elfeed-search-selected-entry))))
  (unless entry (error "No Elfeed entry selected"))

  (let* ((title (elfeed-entry-title entry))
         (clean-title (replace-regexp-in-string "|.*$" "" title)) ;; remove suffix
         (clean-title (replace-regexp-in-string " - ScienceDirect$" "" clean-title))
         (selection (my-feed/zotero-helm-return-data clean-title)))

    (if (not selection)
        (message "Integration cancelled.")

      (let* ((bibtex-str (car selection))
             (source-pdf (cdr selection))
             (elfeed-id (elfeed-entry-id entry))

             ;; 2. Extract BibTeX Key
             (bib-key (if (string-match "@[^\\{]+\{\\([^,]+\\)," bibtex-str)
                          (match-string 1 bibtex-str)
                        (error "No BibTeX Key found")))

             (bib-file (if (listp bibtex-completion-bibliography)
                           (car bibtex-completion-bibliography)
                         bibtex-completion-bibliography)))

        (with-temp-buffer
          (insert "\n" bibtex-str "\n")
          (append-to-file (point-min) (point-max) bib-file))

        ;; C. Update Elfeed Metadata
        ;; Save the filename (e.g. "arxiv_org_123.pdf") and the citation key
        (when bibtex-str
          (elfeed-meta--put entry :bibkey bib-key)
          (elfeed-meta--put entry :bib bibtex-str)
          (elfeed-tag-1 entry 'bib))

        (when source-pdf
          (elfeed-meta--put entry :pdf source-pdf)
          (elfeed-tag-1 entry 'pdf))

        ;; D. Refresh UI
        (when (eq major-mode 'elfeed-search-mode)
          (elfeed-search-update-line))

        (let ((show-buffer (get-buffer "*elfeed-entry*")))
          (when show-buffer
            (with-current-buffer show-buffer
              ;; Check if the buffer is actually showing the entry we just updated
              (when (and (boundp 'elfeed-show-entry)
                         (equal elfeed-show-entry entry))
                (elfeed-show-refresh)))))

        (elfeed-db-save)
        (message "Linked! File: %s" source-pdf)))))
