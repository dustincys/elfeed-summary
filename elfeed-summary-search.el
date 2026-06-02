(defun my-feed/elfeed-fuzzy-search-summaries ()
  "Fuzzy search Elfeed entries based on their AI summary field."
  (interactive)
  (let ((candidates (list))
        ;; 1. DEFINE YOUR SUMMARY KEY HERE
        ;; If your AI tool saves to 'summary', use :summary.
        ;; If it replaces the content, use 'content'.
        (summary-key :summary))

    (message "Loading summaries...")

    ;; 2. Collect entries (Limit to last 2 months or N entries for performance)
    (with-elfeed-db-visit (entry _)
      (let ((summary (elfeed-meta entry summary-key))
            (title (elfeed-entry-title entry)))

        ;; Only include if a summary actually exists
        (when (and summary (stringp summary) (not (string-empty-p summary)))
          ;; Clean up newlines to make the search line cleaner
          (let* ((clean-summary (replace-regexp-in-string "\n" "" summary))
                 ;; Format: "Title -- Summary content"
                 (display-str (format "%s -- %s"
                                      (propertize title 'face 'elfeed-search-title-face)
                                      (propertize clean-summary 'face 'font-lock-comment-face))))
            ;; Push to alist: ( "Display String" . entry-struct )
            (push (cons display-str entry) candidates)))))

    (if (null candidates)
        (message "No AI summaries found.")

      ;; 3. Prompt the user
      (let* ((selection (completing-read "Search Summaries: " candidates))
             (entry (cdr (assoc selection candidates))))

        ;; 4. Display the result
        (when entry
          (elfeed-show-entry entry)
          (message "Opened: %s" (elfeed-entry-title entry)))))))
