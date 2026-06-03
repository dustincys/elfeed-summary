# elfeed-summary

English | [中文](README_zh.md)

An Emacs package that extends [Elfeed](https://github.com/skeeto/elfeed) with AI-powered article summarization, metadata enrichment, full-text search, and export capabilities. Designed for researchers and knowledge workers who manage large RSS feeds of academic papers and articles.

## Features

- **AI Summarization** — Batch-fetch article summaries via an external Node.js script. Tags entries automatically (`summarized`, `NO-CONTEXT`) based on results.
- **PubMed Integration** — Fetch rich metadata from NCBI PubMed: authors, abstracts, DOIs, journal info, and BibTeX. Handles errata/corrections by following the original PMID.
- **Zotero Integration** — Connect to the local Zotero HTTP API to retrieve BibTeX strings and PDF attachments via Helm.
- **LaTeX/PDF Export** — Export current search results to `.tex` or compile directly to PDF with XeLaTeX (supports CJK via `xeCJK`).
- **Fuzzy Summary Search** — `completing-read`-based search across all entries' AI-generated summaries.
- **Enhanced Entry Display** — Overrides elfeed-goodies' display to show enriched metadata (authors, institutions, summary, BibTeX, DOI, abstract, PDF path).
- **Terminal Output** — Print entry metadata in `all`/`summary`/`bib` modes for consumption by external tools.
- **Custom Keybindings** — Minor mode providing `s` (search), `e`/`E` (export), `u` (update entry), `A` (AI summarize), `z` (Zotero integrate).

## Installation

### From MELPA

```
M-x package-install RET elfeed-summary
```

### Manual

Clone the repository and add to your `load-path`:

```bash
git clone https://github.com/dustincys/elfeed-summary.git ~/.emacs.d/lisp/elfeed-summary
```

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp/elfeed-summary")
(require 'elfeed-summary)
```

## Dependencies

| Dependency       | Version        |
|------------------|----------------|
| Emacs            | ≥ 30.2         |
| Elfeed           | ≥ 3.5          |
| elfeed-goodies   | ≥ 0.9          |
| Org              | ≥ 9.6          |
| Helm             | ≥ 3.8 (Zotero) |

### External

- **Node.js** — Required for the AI summarization script (configurable via `elfeed-summary-node-fetch-script`).
- **XeLaTeX** — Required for PDF export with CJK support.
- **Zotero** (optional) — Must be running with Better BibTeX and local HTTP server enabled (port 23119).

## Configuration

```elisp
;; Enable the minor mode for keybindings
(elfeed-summary-mode +1)

;; PubMed API credentials (optional, for metadata enrichment)
(setq elfeed-summary-pubmed-email "your@email.com")
(setq elfeed-summary-pubmed-api-key "your-ncbi-api-key")

;; Path to the Node.js script that fetches article summaries
(setq elfeed-summary-node-fetch-script
      "/path/to/article-summarizer/src/fetch-articles.js")

;; Timeout for batch fetch (default: 7200 seconds)
(setq elfeed-summary-fetch-timeout 3600)

;; Environment file for API keys (default: ~/.env)
(setq elfeed-summary--env-file "~/.env")
```

### Environment File

You can store PubMed credentials in `~/.env`:

```
PUBMED_EMAIL=your@email.com
PUBMED_API_KEY=your-api-key
```

## Keybindings

| Key   | Mode       | Command                                    |
|-------|------------|--------------------------------------------|
| `s`   | Search     | Fuzzy search summaries                     |
| `e`   | Search     | Export results to PDF                      |
| `E`   | Search     | Export results to TeX                      |
| `u`   | Both       | Update entry info from PubMed              |
| `A`   | Both       | Batch AI summarize entries                 |
| `z`   | Both       | Integrate entry with Zotero                |

## Structure

```
elfeed-summary.el              — Main package entry point
elfeed-summary-utils.el        — Shared utilities (HTML, XML, HTTP, JSON helpers)
elfeed-summary-appearance.el   — Enhanced entry display (overrides elfeed-goodies)
elfeed-summary-summarize.el    — Batch AI summarization via external Node.js script
elfeed-summary-pubmed.el       — PubMed E-utilities API client
elfeed-summary-export.el       — LaTeX/PDF export engine
elfeed-summary-search.el       — Fuzzy search across AI summaries
elfeed-summary-print.el        — Terminal output for external tool consumption
elfeed-summary-operations.el   — Cross-module operations (indexing, Zotra)
elfeed-summary-keys.el         — Keybindings and elfeed-summary-mode minor mode
elfeed-summary-zotero.el       — Zotero local API integration
elfeed-summary-zotra.el        — Zotra integration helpers
elfeed-summary-update-entry.el — Entry info update from external sources
elfeed-summary-org-protocol.el — Org protocol integration
```

## Usage Flow

1. **Setup feeds** in Elfeed — add RSS feeds for journals, arXiv categories, or bioRxiv.
2. **Tag entries** with `to-summarize` on the ones you want processed.
3. Press **`A`** in the Elfeed search buffer to batch-fetch AI summaries.
4. Press **`u`** on an entry to enrich it with PubMed metadata (authors, abstract, DOI, BibTeX).
5. Press **`z`** to link a Zotero attachment and BibTeX.
6. Press **`s`** to fuzzy-search your summaries.
7. Press **`e`** or **`E`** to export visible results to PDF or TeX.

## License

GPL v3 — see the file headers for details.

## Author

Yanshuo Chu — [@dustincys](https://github.com/dustincys)
