(defun my-feed/zotero-fetch-bibtex-string (item-key)
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

(defun my-feed/zotero-helm-get-pdf-paths ()
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
                      (parent-key (alist-get 'parentItem data)) ;; <--- NEW: Get Parent Key
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
             attachments)))) ;; <--- FIXED: attachments is now inside mapcar's parens

(defun my-feed/zotero-helm-return-data (&optional default-input)
  "Prompts user to select a Zotero item.
   RETURNS: A cons cell (BibTeX-String . PDF-Path)."
  (interactive)
  (let ((candidates (my-feed/zotero-helm-get-pdf-paths)))
    (helm :sources `((name . "Select Zotero Paper")
                     (candidates . ,candidates)
                     (action . (lambda (candidate)
                                 ;; candidate is formatted as: (Path ParentKey)
                                 (let* ((path (nth 0 candidate))
                                        (key  (nth 1 candidate))
                                        (bib  (my-feed/zotero-fetch-bibtex-string key)))
                                   ;; We return the data structure here
                                   (cons bib path)))))
          :input (when default-input (string-trim default-input))
          :execute-action-at-once-if-one t)))
