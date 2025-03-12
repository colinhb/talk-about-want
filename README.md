# ... Talk About Want

This project processes an EPUB file containing letters, extracts and organizes them by section, and generates synthesized content using an large language model API, which is then rendered to HTML.

- The primary output of this project is at [colinhb.github.io/talk-about-want](https://colinhb.github.io/talk-about-want), which you can visit directly.
- The core and most interesting component is the embedded Go command and package, which you can read about at [prompter/README.md](prompter/README.md).

## Dependencies

- [Plan 9 port](https://9fans.github.io/plan9port/) (`mk`, `rc`, and other utilities)
- [Pandoc](https://pandoc.org/) for document conversion
- [Go](https://golang.org/) for building the prompter tool
- An EPUB file with matching MD5 checksum (see `Want.epub.sum`)
- An [Anthropic API key](https://www.anthropic.com/api)

## Workflow

The project uses a Plan 9 style `mkfile` to orchestrate the following workflow:

1. **EPUB Extraction**: 
   - Validates the EPUB file against its MD5 checksum
   - Unzips the content to a temporary directory

2. **Letter Organization**:
   - Uses the `OEBPS/package.opf` file to determine chapter order
   - Maps chapters to section-letter identifiers using an awk script (`chapters-to-sections`) and `sections.tsv`
   - Uses `pandoc` to convert HTML chapters to plaintext, organizing them by section-letter filenames

3. **Content Synthesis**:
   - The [prompter](prompter/README.md) tool sends letters to a language model API
   - Using templates in `prompt-templates/letter-synthesis.txt`
   - Produces a TSV file [dist/letter-synthesis.tsv](dist/letter-synthesis.tsv) containing synthesized responses with section-letter identifiers

4. **HTML Rendering**:
   - Processes the TSV file into HTML content using an awk script (`tsv-to-html.awk`)
   - Combines with HTML templates to produce the final webpage
   - Copies static assets to the distribution directory

## Usage

To run the entire pipeline:

```sh
mk all
```

To clean up generated files:

```sh
mk clean
```

## Notes

The [`dist/`](dist/) directory contains the TSV and HTML build artifacts, the latter of which is hosted on GitHub Pages, linked above. 

To process the EPUB yourself, you must:

1. Obtain the proper EPUB file and place it in the project root
2. Ensure its MD5 checksum matches the one in `Want.epub.sum`
3. Create a `.env` file with your API key
