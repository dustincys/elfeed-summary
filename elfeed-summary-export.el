;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; export
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
