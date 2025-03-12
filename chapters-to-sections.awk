# Purpose: Maps chapter numbers to section identifiers based on TOC structure
# Usage: Pipe chapter numbers into this script to get output filenames
# Config: Requires a section file via -v sections_file=path
# Example: awk -f map-chapters.awk -v sections_file=custom-sections.tsv < chapters.txt

BEGIN {
    DEBUG=0
    OFS = "\t"
    curr_sec = ""
    last_sec = ""
    sec_num = 1
    sub_num = 1
    
    # Error if sections_file is not provided
    if (!sections_file) {
        printf "ERROR: No section file provided. Use -v sections_file=path\n" > "/dev/stderr"
        exit 1
    }
    
    # Create an array of chapters to skip from a string
    split("7 29 30 47 48 56 57 73 74 79 80 94 95 105 106 127 128 138 139 154 155 167 168 178 179", skip_chapters)

    # Convert to as associative array for faster lookups
    for (i in skip_chapters) {
        should_skip[skip_chapters[i]] = 1
    }
    
    # Load section definitions from TSV file
    section_count = 0
    while ((getline line < sections_file) > 0) {
        if (line ~ /^[0-9]/) {  # Skip header line if exists
            split(line, fields, "\t")
            section_id = fields[1]
            start_ch = fields[2]
            end_ch = fields[3]
            slug = fields[4]
            
            section_start[section_id] = start_ch
            section_end[section_id] = end_ch
            section_slug[section_id] = slug
            
            # Keep track of the highest section number
            if (section_id > max_section) {
                max_section = section_id
            }
            section_count++
        }
    }
    
    # No need to close file explicitly, it will be closed when script ends
    
    if (section_count == 0) {
        printf "ERROR: No valid section definitions found in '%s'.\n", sections_file > "/dev/stderr"
        exit 1
    }
}
{
    ch = $0 + 0 # Handles cases where chapter numbers have trailing letters

    # Section chapters pulled from the epub's table of contents (.../html/ch04.xhtml)
    
    # First, check for chapters we should skip (section titles, Anderson's introductions)	
    if (ch in should_skip) {
		printf "WARNING: Chapter %d explicitly marked to skip - skipping.\n", ch > "/dev/stderr"
        next
    }
    
    # Find which section this chapter belongs to
    curr_sec = ""
    for (s = 1; s <= max_section; s++) {
        if (ch >= section_start[s] && ch <= section_end[s]) {
            curr_sec = section_slug[s]
            sec_num = s
            break
        }
    }
    
    # Skip if chapter doesn't fit any section
    if (curr_sec == "") {
        if (DEBUG) {
            printf "WARNING: Chapter %d does not fit into any defined section range - skipping.\n", ch > "/dev/stderr"
        }
        next
    }

    if (curr_sec != last_sec) {
        sub_num = 1
    } else {
        sub_num++
    }

    if (curr_sec != "") {
        pad_sec_num = sprintf("%02d", sec_num)
        pad_sub_num = sprintf("%02d", sub_num)
        if (DEBUG) {
            print "ch" $0 ".xhtml", pad_sec_num "-" curr_sec "-" pad_sub_num "-ch" $0 ".txt"
        } else {
            print "ch" $0 ".xhtml", pad_sec_num "-" pad_sub_num ".txt"
        }
    }

    last_sec = curr_sec
}
