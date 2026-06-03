# elfeed-summary

[English](README.md) | 中文

为 [Elfeed](https://github.com/skeeto/elfeed) 扩展 AI 文章摘要、元数据丰富、全文搜索和导出功能的 Emacs 包。面向管理大量学术论文和文章 RSS 源的研究人员与知识工作者。

## 功能

- **AI 摘要** — 通过外部 Node.js 脚本批量获取文章摘要。根据结果自动标记（`summarized`、`NO-CONTEXT`）。
- **PubMed 集成** — 从 NCBI PubMed 获取丰富元数据：作者、摘要、DOI、期刊信息、BibTeX。自动处理勘误/更正，追踪至原始 PMID。
- **Zotero 集成** — 连接本地 Zotero HTTP API，通过 Helm 获取 BibTeX 字符串和 PDF 附件。
- **LaTeX/PDF 导出** — 将当前搜索结果导出为 `.tex` 或直接编译为 PDF（通过 XeLaTeX 支持中日韩文字）。
- **模糊摘要搜索** — 基于 `completing-read` 在所有条目的 AI 摘要中进行搜索。
- **增强条目显示** — 覆盖 elfeed-goodies 的显示，展示丰富元数据（作者、机构、摘要、BibTeX、DOI、PDF 路径）。
- **终端输出** — 以 `all`/`summary`/`bib` 模式打印条目元数据，供外部工具使用。
- **自定义快捷键** — 提供 minor mode，包含 `s`（搜索）、`e`/`E`（导出）、`u`（更新条目）、`A`（AI 摘要）、`z`（Zotero 集成）。

## 安装

### MELPA

```
M-x package-install RET elfeed-summary
```

### 手动安装

克隆仓库并添加到 `load-path`：

```bash
git clone https://github.com/dustincys/elfeed-summary.git ~/.emacs.d/lisp/elfeed-summary
```

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp/elfeed-summary")
(require 'elfeed-summary)
```

## 依赖

| 依赖             | 版本           |
|-----------------|---------------|
| Emacs           | ≥ 30.2        |
| Elfeed          | ≥ 3.5         |
| elfeed-goodies  | ≥ 0.9         |
| Org             | ≥ 9.6         |
| Helm            | ≥ 3.8（Zotero）|

### 外部依赖

- **Node.js** — AI 摘要脚本所需（通过 `elfeed-summary-node-fetch-script` 配置路径）。
- **XeLaTeX** — PDF 导出（支持中日韩文字）所需。
- **Zotero**（可选）— 需运行并启用 Better BibTeX 插件和本地 HTTP 服务器（端口 23119）。

## 配置

```elisp
;; 启用 minor mode 以激活快捷键
(elfeed-summary-mode +1)

;; PubMed API 凭证（可选，用于元数据丰富）
(setq elfeed-summary-pubmed-email "your@email.com")
(setq elfeed-summary-pubmed-api-key "your-ncbi-api-key")

;; AI 摘要 Node.js 脚本路径
(setq elfeed-summary-node-fetch-script
      "/path/to/article-summarizer/src/fetch-articles.js")

;; 批量获取超时时间（默认 7200 秒）
(setq elfeed-summary-fetch-timeout 3600)

;; API 密钥环境文件（默认 ~/.env）
(setq elfeed-summary--env-file "~/.env")
```

### 环境文件

可在 `~/.env` 中存储 PubMed 凭证：

```
PUBMED_EMAIL=your@email.com
PUBMED_API_KEY=your-api-key
```

## 快捷键

| 按键  | 模式       | 功能                  |
|------|-----------|----------------------|
| `s`  | Search    | 模糊搜索摘要            |
| `e`  | Search    | 导出结果为 PDF         |
| `E`  | Search    | 导出结果为 TeX         |
| `u`  | 两者       | 从 PubMed 更新条目信息  |
| `A`  | 两者       | 批量 AI 摘要条目       |
| `z`  | 两者       | 与 Zotero 集成条目     |

## 项目结构

```
elfeed-summary.el              — 主入口文件
elfeed-summary-utils.el        — 共享工具函数（HTML、XML、HTTP、JSON）
elfeed-summary-appearance.el   — 增强条目显示（覆盖 elfeed-goodies）
elfeed-summary-summarize.el    — 批量 AI 摘要（调用外部 Node.js 脚本）
elfeed-summary-pubmed.el       — PubMed E-utilities API 客户端
elfeed-summary-export.el       — LaTeX/PDF 导出引擎
elfeed-summary-search.el       — AI 摘要模糊搜索
elfeed-summary-print.el        — 供外部工具使用的终端输出
elfeed-summary-operations.el   — 跨模块操作（索引、Zotra）
elfeed-summary-keys.el         — 快捷键与 elfeed-summary-mode minor mode
elfeed-summary-zotero.el       — Zotero 本地 API 集成
elfeed-summary-zotra.el        — Zotra 集成辅助
elfeed-summary-update-entry.el — 从外部来源更新条目信息
elfeed-summary-org-protocol.el — Org protocol 集成
```

## 使用流程

1. 在 Elfeed 中**配置 RSS 源** — 添加期刊、arXiv 分类或 bioRxiv 的 RSS。
2. 将需要处理的条目**标记** `to-summarize`。
3. 在 Elfeed 搜索缓冲区按 **`A`** 批量获取 AI 摘要。
4. 在条目上按 **`u`** 从 PubMed 丰富元数据（作者、摘要、DOI、BibTeX）。
5. 按 **`z`** 关联 Zotero 附件和 BibTeX。
6. 按 **`s`** 对摘要进行模糊搜索。
7. 按 **`e`** 或 **`E`** 将可见结果导出为 PDF 或 TeX。

## 许可证

GPL v3 — 详见各文件头部。

## 作者

Yanshuo Chu — [@dustincys](https://github.com/dustincys)
