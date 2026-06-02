(defun elfeed-summary--pubmed-build-url (base params)
  (concat
   base
   "?"
   (url-build-query-string
    (append
     params
     `(("email" ,elfeed-summary--pubmed-email))
     (when elfeed-summary--pubmed-api-key
       `(("api_key" ,elfeed-summary--pubmed-api-key)))))))

(defun elfeed-summary--pubmed-doi-to-pmid (doi)
  (let*
      ((url-request-extra-headers
        '(("User-Agent" . "Emacs")))
       (url
        (elfeed-summary--pubmed-build-url
         "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
         `(("db" "pubmed")
           ("retmode" "json")
           ("term" ,doi))))
       (json
        (elfeed-summary--http-get-json url))
       (esearch
        (alist-get 'esearchresult json))
       (ids
        (alist-get 'idlist esearch)))
    (car ids)))

(defun elfeed-summary--pubmed-fetch-xml (pmid)
  (let*
      ((url-request-extra-headers
        '(("User-Agent" . "Emacs")))
       (url
        (elfeed-summary--pubmed-build-url
         "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
         `(("db" "pubmed")
           ("retmode" "xml")
           ("id" ,pmid)))))
    (elfeed-summary--http-get-xml url)))

(defun elfeed-summary--pubmed-find-original-pmid (xml)
  (let*
      ((pubmed-article
        (elfeed-summary--xml-first-child
         xml
         'PubmedArticle))
       (comments-list
        (elfeed-summary--xml-path
         pubmed-article
         'MedlineCitation
         'CommentsCorrectionsList))
       (comments
        (when comments-list
          (elfeed-summary--xml-get-children
           comments-list
           'CommentsCorrections))))
    (catch 'found
      (dolist (c comments)
        (let
            ((ref-type
              (cdr
               (assoc
                'RefType
                (xml-node-attributes c)))))
          (when
              (member
               ref-type
               '("ErratumFor"
                 "CorrectionFor"))
            (let
                ((pmid-node
                  (elfeed-summary--xml-first-child
                   c
                   'PMID)))
              (when pmid-node
                (throw
                 'found
                 (elfeed-summary--xml-node-text
                  pmid-node)))))))
      nil)))

(defun elfeed-summary--pubmed-extract-doi (pubmed-article)
  (let*
      ((article-id-list
        (elfeed-summary--xml-path
         pubmed-article
         'PubmedData
         'ArticleIdList))
       (ids
        (when article-id-list
          (elfeed-summary--xml-get-children
           article-id-list
           'ArticleId))))
    (catch 'doi
      (dolist (id ids)
        (when
            (string=
             (cdr
              (assoc
               'IdType
               (xml-node-attributes id)))
             "doi")
          (throw
           'doi
           (elfeed-summary--xml-node-text id))))
      nil)))

(defun elfeed-summary--pubmed-extract-year (article-node)
  (or
   (elfeed-summary--xml-node-text
    (elfeed-summary--xml-path
     article-node
     'Journal
     'JournalIssue
     'PubDate
     'Year))
   ""))

(defun elfeed-summary--pubmed-extract-abstract (article-node)
  (let*
      ((abstract-node
        (elfeed-summary--xml-first-child
         article-node
         'Abstract))
       (abstract-nodes
        (when abstract-node
          (elfeed-summary--xml-get-children
           abstract-node
           'AbstractText))))
    (string-join
     (mapcar
      (lambda (node)
        (let
            ((label
              (cdr
               (assoc
                'Label
                (xml-node-attributes node))))
             (text
              (elfeed-summary--xml-node-text node)))
          (if
              (and label
                   (not
                    (string-empty-p label)))
              (format
               "%s: %s"
               label
               text)
            text)))
      abstract-nodes)
     "\n\n")))

(defun elfeed-summary--pubmed-extract-authors (article-node)
  (let*
      ((author-list
        (elfeed-summary--xml-first-child
         article-node
         'AuthorList))
       (authors
        (when author-list
          (elfeed-summary--xml-get-children
           author-list
           'Author))))
    (mapcar
     (lambda (author)
       (let*
           ((lastname
             (elfeed-summary--xml-node-text
              (elfeed-summary--xml-first-child
               author
               'LastName)))
            (firstname
             (elfeed-summary--xml-node-text
              (elfeed-summary--xml-first-child
               author
               'ForeName)))
            (collective
             (elfeed-summary--xml-node-text
              (elfeed-summary--xml-first-child
               author
               'CollectiveName)))
            (fullname
             (if collective
                 collective
               (string-join
                (delq nil
                      (list
                       firstname
                       lastname))
                " ")))
            (affs
             (delete-dups
              (delq
               nil
               (mapcar
                (lambda (aff-info)
                  (elfeed-summary--xml-node-text
                   (elfeed-summary--xml-first-child
                    aff-info
                    'Affiliation)))
                (elfeed-summary--xml-get-children
                 author
                 'AffiliationInfo))))))
         `((name . ,fullname)
           (affiliations . ,affs))))
     authors)))

(defun elfeed-summary--pubmed-extract-metadata (xml)
  (let*
      ((pubmed-article
        (elfeed-summary--xml-first-child
         xml
         'PubmedArticle))
       (medline
        (elfeed-summary--xml-first-child
         pubmed-article
         'MedlineCitation))
       (article-node
        (elfeed-summary--xml-first-child
         medline
         'Article))
       (doi
        (elfeed-summary--pubmed-extract-doi
         pubmed-article))
       (title
        (elfeed-summary--xml-node-text
         (elfeed-summary--xml-first-child
          article-node
          'ArticleTitle)))
       (journal
        (elfeed-summary--xml-node-text
         (elfeed-summary--xml-path
          article-node
          'Journal
          'Title)))
       (year
        (elfeed-summary--pubmed-extract-year
         article-node))
       (abstract
        (elfeed-summary--pubmed-extract-abstract
         article-node))
       (authors
        (elfeed-summary--pubmed-extract-authors
         article-node)))
    `((doi . ,doi)
      (title . ,title)
      (journal . ,journal)
      (year . ,year)
      (abstract . ,abstract)
      (authors . ,authors))))

(defun elfeed-summary--pubmed-fetch-by-pmid (pmid)
  (let*
      ((xml
        (elfeed-summary--pubmed-fetch-xml pmid))
       (original-pmid
        (elfeed-summary--pubmed-find-original-pmid xml)))
    (when original-pmid
      (message
       "Correction detected -> original PMID: %s"
       original-pmid)
      (setq xml
            (elfeed-summary--pubmed-fetch-xml
             original-pmid)))
    (elfeed-summary--pubmed-extract-metadata xml)))

(defun elfeed-summary--pubmed-fetch-by-doi (doi)
  (let
      ((pmid
        (elfeed-summary--pubmed-doi-to-pmid doi)))
    (unless pmid
      (error
       "No PMID found for DOI: %s"
       doi))
    (elfeed-summary--pubmed-fetch-by-pmid pmid)))

(defun elfeed-summary--pubmed-fetch-by-url (url)
  (let
      ((pmid
        (elfeed-summary--pubmed-url-to-pmid url)))
    (unless pmid
      (error
       "Could not extract PMID from URL"))
    (elfeed-summary--pubmed-fetch-by-pmid pmid)))
