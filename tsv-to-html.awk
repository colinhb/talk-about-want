BEGIN {
    FS="\t"

    # Load section headings from letter-sections.tsv
    while ((getline line < "sections.tsv") > 0) {
        split(line, fields, "\t")
        if (fields[1] ~ /^[0-9]+$/) {  # Skip header line
            section_id = fields[1]
            heading = fields[5]
            slug = fields[4]
            
            # Store section heading and slug in associative arrays
            section_heading[section_id] = heading
            section_slug[section_id] = slug
        }
    }
    close("letter-sections.tsv")
    
    current_section = ""
    letter_count = 0
    
    # Generate table of contents
    print "	<h2>Letters</h2>"
	print "    <ol class=\"toc\">"
    for (i = 1; i <= length(section_heading); i++) {
        if (section_heading[i] != "") {
            print "        <li><a href=\"#" section_slug[i] "\">" section_heading[i] "</a></li>"
        }
    }
    print "    </ol>"
    print ""
}

{
    # Extract section from file ID (e.g., "01-03.txt" -> "1")
    section = substr($1, 1, 2)
    section_num = section + 0  # Convert to number to remove leading zero
    
    # If we've moved to a new section, print a heading
    if (section != current_section) {
        if (current_section != "") print ""  # Add space between sections
        print "    <h3 id=\"" section_slug[section_num] "\">" section_heading[section_num] "</h2>"
        current_section = section
        letter_count = 1
    }
    
    # Print the letter with its number
	content = $2
    gsub(/\\n/, " ", content)  # Replace \n with HTML line breaks
    print "    <div class=\"letter\"><span class=\"number\">" letter_count ".</span> " content "</div>"
    letter_count++
}
