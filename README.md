# ... Talk About Want

**RAW NOTES FOR NOW**

## Notes

The main script (`main.rc`):

   - Extracts chapter references from the package.opf file
   - Maps each chapter to its corresponding sections and subsections using `map-chapters.awk`
   - Converts HTML chapters into plain text using `pandoc`
   - Writes the plain text out to the `extracted` directory with the naming pattern: `{{section-number}}-{{subsection-number}}.txt`

The mapping from chapters to sections and subsections was implemented manually after reviewing the book's table of contents.

In total, the content extraction requires: a POSIX compliant shell and `awk` implementations and `pandoc`.

<!--

## Categories

The script organizes content into the following categories based on chapter ranges (pulled from the original book's table of contents):

- On Fantasies (chapters 7-28)
- Rough and Ready (chapters 29-46)
- To Be Worshiped (chapters 47-55)
- Off Limits (chapters 56-72)
- The Captive (chapters 73-78)
- Kink (chapters 79-93)
- Strangers (chapters 94-104)
- Power and Submission (chapters 105-126)
- Exploration (chapters 127-137)
- More, More, More (chapters 138-153)
- The Watchers and the Watched (chapters 154-166)
- I Have Always Had a Thing For (chapters 167-177)
- Gently, Gently (chapters 178-202)

-->
