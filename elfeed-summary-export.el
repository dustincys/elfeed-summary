;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; export
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'elfeed-summary-utils)

(defun elfeed-summary--entry-to-tex (entry)
  "Format a single Elfeed ENTRY as a LaTeX section.
Returns a string with \\section, metadata, summary, and abstract."
  (let* ((title (elfeed-entry-title entry))
         (link (elfeed-entry-link entry))
         (date (format-time-string "%Y-%m-%d"
                                   (seconds-to-time (elfeed-entry-date entry))))
         (authors (elfeed-meta entry :authors))
         (doi (elfeed-meta entry :doi))
         (summary (elfeed-meta entry :summary))
         (abstract (elfeed-meta entry :abstract))
         (bib (elfeed-meta entry :bib))
         (feed (elfeed-feed-title (elfeed-entry-feed entry))))
    (with-temp-buffer
      (insert (format "\\section{%s}\n" (or title "Untitled")))
      (insert "\\begin{itemize}\n")
      (when feed
        (insert (format "  \\item Feed: %s\n" feed)))
      (when date
        (insert (format "  \\item Date: %s\n" date)))
      (when doi
        (insert (format "  \\item DOI: \\href{https://doi.org/%s}{%s}\n" doi doi)))
      (when link
        (insert (format "  \\item URL: \\url{%s}\n" link)))
      (when authors
        (insert "  \\item Authors: ")
        (dolist (a authors)
          (insert (format "%s, " (alist-get 'name a))))
        (delete-char -2)
        (insert "\n"))
      (insert "\\end{itemize}\n")
      (when summary
        (insert (format "\\subsection*{Summary}\n%s\n" summary)))
      (when abstract
        (insert (format "\\subsection*{Abstract}\n%s\n" abstract)))
      (when bib
        (insert (format "\\subsection*{BibTeX}\n\\begin{MyVerbatim}\n%s\n\\end{MyVerbatim}\n" bib)))
      (insert "\n")
      (buffer-string))))

(defun elfeed-summary--export-search-to-tex
    (&optional output-base compile)
  "Export current Elfeed search results to TeX/PDF.
OUTPUT-BASE:
  output path without extension.
COMPILE:
  if non-nil, run xelatex twice."
  (interactive)
  (let* ((entries
          (elfeed-summary--search-entries))
         (output-base
          (or output-base
              (expand-file-name
               (format
                "elfeed-export-%s"
                (format-time-string
                 "%Y%m%d-%H%M%S"))
               default-directory)))
         (tex-file
          (concat output-base ".tex"))
         (default-directory
          (file-name-directory tex-file)))

    ;; write tex
    (with-temp-file tex-file
      (insert
       "
\\documentclass[11pt]{article}
\\usepackage{fontspec}
\\usepackage{xeCJK}
\\usepackage{hyperref}
\\usepackage[a4paper,margin=1in]{geometry}
\\usepackage{fvextra}
\\setmainfont{DejaVu Serif}
\\setCJKmainfont{Noto Serif CJK SC}
\\hypersetup{
  colorlinks=true,
  linkcolor=blue,
  urlcolor=blue
}
\\DefineVerbatimEnvironment
  {MyVerbatim}
  {Verbatim}
  {
    breaklines=true,
    breakanywhere=true,
    fontsize=\\small
  }
\\title{文献库查询}
\\author{Yanshuo Chu}
\\date{\\today}
\\begin{document}
\\maketitle
\\tableofcontents
\\newpage
")
      ;; entries
      (dolist (entry entries)
        (insert
         (elfeed-summary--entry-to-tex entry)))
      ;; end
      (insert
       "\n\\end{document}\n"))
    (message
     "Written TeX: %s"
     tex-file)
    ;; compile
    (when compile
      ;; first pass
      (shell-command
       (format
        "xelatex -interaction=nonstopmode %s"
        (shell-quote-argument
         (file-name-nondirectory tex-file))))
      ;; second pass for TOC
      (shell-command
       (format
        "xelatex -interaction=nonstopmode %s"
        (shell-quote-argument
         (file-name-nondirectory tex-file))))
      (message
       "Compiled PDF: %s.pdf"
       output-base))
    tex-file))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; convenience command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun elfeed-summary--export-search-to-pdf ()
  "Export current Elfeed search results directly to PDF."
  (interactive)
  (elfeed-summary--export-search-to-tex nil t))

(provide 'elfeed-summary-export)
;;; elfeed-summary-export.el ends here
