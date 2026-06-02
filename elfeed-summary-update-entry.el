(defun my-feed/update-nature-entry (&optional entry)
  "Update Nature paper metadata for ENTRY.
Extract JSON-LD metadata from Nature article page:
- title
- abstract
- authors
- DOI
- institution
If ENTRY is nil, use current Elfeed entry."
  (interactive)
  (let* ((entry (or entry (my-feed/get-current-entry)))
         (link (elfeed-entry-link entry)))
    (message "DEBUG: Entry link: %s" link)
    (unless link
      (error "No entry link found"))
    (condition-case err
        (let ((buffer (url-retrieve-synchronously link t t 15)))
          (message "DEBUG: HTTP buffer retrieved: %s" (if buffer "yes" "no"))
          (unless buffer
            (error "Failed retrieving Nature page"))
          (unwind-protect
              (with-current-buffer buffer
                ;; skip HTTP headers
                (goto-char (point-min))
                (message "DEBUG: Buffer size: %d" (buffer-size))
                (unless (re-search-forward "\r?\n\r?\n" nil t)
                  (error "Cannot find HTTP header end"))
                (message "DEBUG: Headers skipped, point at: %d" (point))
                ;; parse html
                (let* ((dom (libxml-parse-html-region (point) (point-max)))
                       (script-nodes (dom-by-tag dom 'script))
                       (json-text nil))
                  (message "DEBUG: DOM parsed, script nodes found: %d" (length script-nodes))
                  ;; find application/ld+json
                  (dolist (node script-nodes)
                    (let ((type (dom-attr node 'type)))
                      (when (string= type "application/ld+json")
                        (setq json-text (car (dom-children node)))
                        (message "DEBUG: Found ld+json script, length: %d"
                                 (if json-text (length json-text) 0)))))
                  (unless json-text
                    (error "No JSON-LD found"))
                  (message "DEBUG: JSON-LD text begins: %s..."
                           (substring json-text 0 (min 80 (length json-text))))
                  ;; parse JSON
                  (let* ((json-object-type 'alist)
                         (json-array-type 'list)
                         (json-key-type 'symbol)
                         (data (json-read-from-string json-text))
                         (paper (alist-get 'mainEntity data))
                         (title (alist-get 'headline paper))
                         (abstract (alist-get 'description paper))
                         (doi-url (alist-get 'sameAs paper))
                         (doi (when doi-url
                                (replace-regexp-in-string "^https://doi.org/" "" doi-url)))
                         (authors-raw (alist-get 'author paper))
                         (authors (mapcar (lambda (a) (list :name (alist-get 'name a)))
                                          authors-raw))
                         (last-author (car (last authors-raw)))
                         (affiliations (alist-get 'affiliation last-author))
                         (first-affiliation (cond ((listp affiliations) (car affiliations))
                                                  ((vectorp affiliations) (aref affiliations 0))
                                                  (t nil)))
                         (institution (when first-affiliation
                                        (alist-get 'name first-affiliation)))
                         (result `((title . ,title)
                                   (abstract . ,abstract)
                                   (doi . ,doi)
                                   (institution . ,institution)
                                   (authors . ,authors))))
                    (message "DEBUG: Title: %s" (or title "none"))
                    (message "DEBUG: Abstract: %s..." (substring (or abstract "") 0 (min 80 (length (or abstract "")))))
                    (message "DEBUG: DOI: %s" (or doi "none"))
                    (message "DEBUG: Authors count: %d" (length authors))
                    (message "DEBUG: Institution: %s" (or institution "none"))
                    ;; update metadata
                    (elfeed-meta--put entry :title title)
                    (elfeed-meta--put entry :abstract abstract)
                    (elfeed-meta--put entry :doi doi)
                    (elfeed-meta--put entry :authors authors)
                    (elfeed-meta--put entry :author_corresponding_institution institution)
                    ;; persist db
                    (elfeed-db-save)
                    (message "DEBUG: Metadata saved to database.")
                    ;; refresh UI
                    (when (get-buffer "*elfeed-search*")
                      (with-current-buffer "*elfeed-search*"
                        (elfeed-search-update :force))
                      (message "DEBUG: Search buffer refreshed."))
                    (when (get-buffer "*elfeed-entry*")
                      (with-current-buffer "*elfeed-entry*"
                        (elfeed-show-refresh))
                      (message "DEBUG: Entry show buffer refreshed."))
                    (message "Updated Nature metadata: %s" doi)
                    result)))
            ;; cleanup
            (kill-buffer buffer)
            (message "DEBUG: HTTP buffer killed.")))
      (error
       (message "Nature metadata update failed: %s (%S)" link err)
       (message "DEBUG: Error details: %s" (error-message-string err))
       nil))))


(defun my-feed/update-pubmed-entry (&optional entry)
  (interactive)
  (let* ((entry (or entry (my-feed/get-current-entry)))
         (link (elfeed-entry-link entry)))
    (unless link
      (error "No entry link found"))
    (unless (string-match "pubmed\\.ncbi\\.nlm\\.nih\\.gov" link)
      (error "Not a PubMed URL"))
    (let* ((pmid (my-feed/pubmed-url-to-pmid link)))
      (unless pmid
        (error "Cannot extract PMID from PubMed URL"))
      (message "PubMed PMID: %s" pmid)
      (condition-case err
          (let* ((data (my-feed/pubmed-fetch-by-pmid pmid))
                 (doi (alist-get 'doi data))
                 (title (alist-get 'title data))
                 (abstract (alist-get 'abstract data))
                 (authors-full (alist-get 'authors data))
                 (authors (mapcar (lambda (a)
                                    (list :name (alist-get 'name a)))
                                  authors-full))
                 (last-author (car (last authors-full)))
                 (institution (car (alist-get 'affiliations last-author)))
                 (result `((title . ,title)
                           (abstract . ,abstract)
                           (doi . ,doi)
                           (pmid . ,pmid)
                           (institution . ,institution)
                           (authors . ,authors))))
            (message "DEBUG: Title: %s" (or title "none"))
            (message "DEBUG: Authors count: %d" (length authors))
            (message "DEBUG: Authors: %S" authors)
            (message "DEBUG: Institution: %s" (or institution "none"))
            (elfeed-meta--put entry :title title)
            (elfeed-meta--put entry :abstract abstract)
            (elfeed-meta--put entry :doi doi)
            (elfeed-meta--put entry :pmid pmid)
            (elfeed-meta--put entry :authors authors)
            (elfeed-meta--put entry :author_corresponding_institution institution)
            (elfeed-db-save)
            (when (get-buffer "*elfeed-search*")
              (with-current-buffer "*elfeed-search*"
                (elfeed-search-update :force)))
            (when (get-buffer "*elfeed-entry*")
              (with-current-buffer "*elfeed-entry*"
                (elfeed-show-refresh)))
            (message "Updated PubMed metadata: PMID=%s DOI=%s" pmid doi)
            result)
        (error
         (message "PubMed metadata update failed: %s (%S)" link err)
         (message "DEBUG: Error details: %s" (error-message-string err))
         nil)))))


(defun my-feed/update-science-entry (&optional entry)
  "Update Science paper metadata for ENTRY using PubMed."
  (interactive)
  (let* ((entry
          (or entry
              (my-feed/get-current-entry)))
         (link
          (elfeed-entry-link entry)))
    (unless link
      (error "No entry link found"))
    (let* ((doi
            (my-feed/science-url-to-doi link)))
      (unless doi
        (error "Cannot extract DOI from Science URL"))
      (message
       "Science DOI: %s"
       doi)
      (condition-case err
          (let* ((data
                  (my-feed/pubmed-fetch-by-doi doi))
                 (title
                  (alist-get 'title data))
                 (abstract
                  (alist-get 'abstract data))
                 (authors-full
                  (alist-get 'authors data))
                 (authors
                  (mapcar
                   (lambda (a)
                     (list
                      :name
                      (alist-get 'name a)))
                   authors-full))
                 (last-author
                  (car (last authors-full)))
                 (institution
                  (car
                   (alist-get
                    'affiliations
                    last-author)))
                 (result
                  `((title . ,title)
                    (abstract . ,abstract)
                    (doi . ,doi)
                    (institution . ,institution)
                    (authors . ,authors))))
            (message
             "DEBUG: Title: %s"
             (or title "none"))
            (message
             "DEBUG: Authors count: %d"
             (length authors))
            (message
             "DEBUG: Authors: %S"
             authors)
            (message
             "DEBUG: Institution: %s"
             (or institution "none"))
            ;; update elfeed metadata
            (elfeed-meta--put
             entry
             :title
             title)
            (elfeed-meta--put
             entry
             :abstract
             abstract)
            (elfeed-meta--put
             entry
             :doi
             doi)
            (elfeed-meta--put
             entry
             :authors
             authors)
            (elfeed-meta--put
             entry
             :author_corresponding_institution
             institution)
            ;; persist db
            (elfeed-db-save)
            ;; refresh UI
            (when (get-buffer "*elfeed-search*")
              (with-current-buffer "*elfeed-search*"
                (elfeed-search-update :force)))
            (when (get-buffer "*elfeed-entry*")
              (with-current-buffer "*elfeed-entry*"
                (elfeed-show-refresh)))
            (message
             "Updated Science metadata: %s"
             doi)
            result)
        (error
         (message
          "Science metadata update failed: %s (%S)"
          link
          err)
         (message
          "DEBUG: Error details: %s"
          (error-message-string err))
         nil)))))

(defun my-feed/update-entry-info
    (&optional entry)
  "Dynamically update metadata for ENTRY."
  (interactive)
  (let* ((entry
          (or entry
              (my-feed/get-current-entry)))
         (link
          (elfeed-entry-link entry)))
    (unless link
      (error "No entry link found"))
    (cond
     ;; bioRxiv
     ((string-match-p
       "biorxiv\\.org"
       link)
      (message
       "Detected bioRxiv paper")
      (my-feed/update-biorxiv-entry
       entry))
     ;; Nature
     ((string-match-p
       "nature\\.com"
       link)
      (message
       "Detected Nature paper")
      (my-feed/update-nature-entry
       entry))
     ;; Science
     ((string-match-p
       "science\\.org"
       link)
      (message
       "Detected Science paper")
      (my-feed/update-science-entry
       entry))
     ;; Pubmed
     ;; https://pubmed.ncbi.nlm.nih.gov
     ((string-match-p
       "pubmed\\.ncbi\\.nlm\\.nih\\.gov\\|pubmed\\.gov"
       link)
      (message
       "Detected pubmed paper")
      (my-feed/update-pubmed-entry
       entry))
     ;; unsupported
     (t
      (message
       "No metadata updater available for: %s"
       link)))))

(defun my-feed/update-all-biorxiv-entries ()
  "Batch update all bioRxiv entries in Elfeed DB."
  (interactive)
  (let ((updated 0))
    (maphash
     (lambda (_id entry)
       (if (my-feed/bioRxiv-high-score-p entry)
           (progn
             (setq updated (1+ updated))
             (message "Updating bioRxiv entry %d..." updated)
             (my-feed/update-biorxiv-entry entry))))
     elfeed-db-entries)
    ;; persist once
    (elfeed-db-save)
    ;; refresh elfeed search
    (when (get-buffer "*elfeed-search*")
      (with-current-buffer "*elfeed-search*"
        (elfeed-search-update :force)))
    ;; refresh show buffer
    (when (get-buffer "*elfeed-show*")
      (with-current-buffer "*elfeed-show*"
        (when (derived-mode-p 'elfeed-show-mode)
          (elfeed-show-refresh))))
    (message
     "Processed %d bioRxiv entries (updated)"
     updated)))


(defun my-feed/update-biorxiv-entry-async (entry)
  "Asynchronously update bioRxiv metadata for ENTRY."
  (let* ((doi (or (elfeed-meta entry :doi)
                  (my-feed/extract-biorxiv-doi (elfeed-entry-link entry)))))
    (when doi
      (url-retrieve (format "https://api.biorxiv.org/details/biorxiv/%s" doi)
                    (lambda (status)
                      (let ((json-object-type 'alist)
                            (json-array-type 'list)
                            (json-key-type 'symbol))
                        (condition-case err
                            (progn
                              (goto-char (point-min))
                              (re-search-forward "\r?\n\r?\n" nil t)
                              (let* ((json (json-read))
                                     (collection (alist-get 'collection json))
                                     (paper (cond ((listp collection)
                                                   (car (last collection)))
                                                  ((and collection (listp (car collection)))
                                                   collection)
                                                  (t nil))))
                                (when paper
                                  (let ((authors-raw (alist-get 'authors paper))
                                        (abstract (alist-get 'abstract paper))
                                        (api-doi (alist-get 'doi paper))
                                        (author_corresponding (alist-get 'author_corresponding paper))
                                        (institution (alist-get 'author_corresponding_institution paper)))
                                    (when api-doi (elfeed-meta--put entry :doi api-doi))
                                    (when abstract (elfeed-meta--put entry :abstract abstract))
                                    (when authors-raw
                                      (let ((authors (mapcar (lambda (x) (list :name (string-trim x)))
                                                             (split-string authors-raw ";"))))
                                        (when (and authors author_corresponding)
                                          (setcar (last authors) (list :name (string-trim author_corresponding))))
                                        (elfeed-meta--put entry :authors authors)))
                                    (when institution (elfeed-meta--put entry :author_corresponding_institution institution))
                                    (elfeed-db-save)
                                    (when (get-buffer "*elfeed-search*")
                                      (with-current-buffer "*elfeed-search*"
                                        (elfeed-search-update :force)))
                                    (message "Updated bioRxiv metadata: %s" api-doi)))))
                          (error (message "bioRxiv async update failed: %S" err))))
                      nil t)))))


(defun my-feed/elfeed-auto-update-biorxiv (type entry db-entry)
  (when (and (eq type :rss)
             (string-match-p "biorxiv" (elfeed-feed-url (elfeed-db-get-feed (elfeed-entry-feed-id db-entry)))))
    (run-with-idle-timer 2 nil #'my-feed/update-biorxiv-entry-async db-entry)))
