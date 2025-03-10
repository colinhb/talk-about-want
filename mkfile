# Plan 9 style mkfile for the talk-about-want project
#
# This project processes an EPUB file, extracts letters, performs synthesis using
# language models, and generates HTML content.
#
# Main targets:
#   all: Default target, builds the HTML index
#   epub: Extract content from the EPUB file
#   letters: Extract letters from the EPUB content
#   clean: Remove build artifacts

MKSHELL=rc

tmp=tmp

epub_file=Want.epub
epub_sum=$epub_file.sum

epub_dir=$tmp/epub
epub_marker=$epub_dir/done
opf=$epub_dir/OEBPS/package.opf

letters_dir=$tmp/letters
letters_marker=$letters_dir/done

sections_script=chapters-to-sections.awk
sections_file=sections.tsv

dotenv=.env

p_bin=bin/prompter
p_output_dir=$tmp/prompter
p_file=prompt-templates/letter-synthesis.txt

index=dist/html/index.html
html_script=tsv-to-html.awk
t=html-templates # short variable name to reduce line length

synthesis_file=dist/letter-synthesis.tsv

# Default target
all:V: index

epub:V: $epub_marker

$epub_marker: $epub_file $epub_sum
	# Check the EPUB file's checksum
	sum1=`{cat $epub_sum | awk '{print $1}'}
	sum2=`{md5sum $epub_file | awk '{print $1}'}
	if(! ~ $sum1 $sum2) {
		echo Error: EPUB file checksum mismatch >[1=2]
		exit 1
	}
	# Create the epub target directory
	mkdir -p $epub_dir || {
		echo Error: Failed to create $epub_dir directory >[1=2]
		exit 1
	}
	# Unzip the epub to the temporary directory
	# NOTE: we're using the unix unzip command here
	u unzip $epub_file -d $epub_dir || {
		echo Error: Failed to extract the EPUB file >[1=2]
		exit 1
	}
	if(! test -f $opf) {
		echo Error: $opf file not found >[1=2]
		exit 1
	}
	touch $epub_marker || {
		echo Error: Failed to create marker file $epub_marker >[1=2]
		exit 1
	}

letters:V: $letters_marker

$letters_marker: $epub_marker $sections_script
	# Create the letters target directory
	mkdir -p $letters_dir || {
		echo Error: Failed to create $letters_dir directory >[1=2]
		exit 1
	}
	html_dir=$epub_dir/OEBPS/html
	# Check existence of the html directory
	if(! test -d $html_dir) {
		echo Error: HTML directory $html_dir not found >[1=2]
		exit 1
	}
	# Extract the letters from the EPUB file
		grep '<itemref' $opf |
		sed -e 's/.*idref="ch([^"]+)".*/\1/' |
		awk -f $sections_script -v sections_file=$sections_file |
		while(l=`{read}) {
			in=$l(1)
			out=$l(2)
			echo Converting $in → $out
			if(test -f $html_dir/$in) {
				pandoc $html_dir/$in -o $letters_dir/$out -t plain || { 
					echo Error: Failed converting $html_dir/$in >[1=2]
					exit 1
                }
			}
			if not {
				echo Warning: Source file $html_dir/$in not found >[1=2]
			}
		}
	touch $letters_marker || {
		echo Error: Failed to create marker file $letters_marker >[1=2]
		exit 1
	}

$p_bin: ./prompter/prompter.go ./prompter/cmd/main.go
	mkdir -p bin || {
        echo Error: Failed to create bin directory >[1=2]
        exit 1
    }
	cd prompter && go build -o ../$p_bin ./cmd/
	chmod +x $p_bin

$synthesis_file: $epub_marker $letters_marker $dotenv $p_bin $p_file
	# Create the prompter output directory
	mkdir -p $p_output_dir || {
		echo Error: Failed to create $p_output_dir directory >[1=2]
        exit 1
    }
    mkdir -p dist || {
        echo Error: Failed to create dist directory >[1=2]
		exit 1
	}
	now=`{date -n}
	raw=$p_output_dir/$now-letter-synthesis-raw.tsv
	sorted=$p_output_dir/$now-letter-synthesis-sorted.tsv
	touch $raw $sorted || {
		echo Error: Failed to create temporary output files >[1=2]
		exit 1
	}
	. ./$dotenv
	find $letters_dir/*.txt | ./$p_bin -k $ANTHROPIC_API_KEY -p $p_file -f | tee -a $raw
	sort $raw > $sorted || {
		echo Error: Failed to sort the raw file >[1=2]
		exit 1
	}
	cp $sorted $target || {
		echo Error: Failed to copy $sorted to $target >[1=2]
		exit 1
	}

index:V: $index

$index: $synthesis_file $sections_file $html_script $t/header.html $t/content-intro.html $t/footer.html
    mkdir -p dist/html || {
        echo Error: Failed to create dist/html directory >[1=2]
        exit 1
    }
	echo '	<h2>Prompt</h2>' > $tmp/content-prompt.html
	echo '	<pre class="prompt">' >> $tmp/content-prompt.html
	echo '		<code>' >> $tmp/content-prompt.html
	cat $p_file | tr '<' '&lt;' | tr '>' '&gt;' >> $tmp/content-prompt.html
	echo '		</code>' >> $tmp/content-prompt.html
	echo '	</pre>' >> $tmp/content-prompt.html
	cat $synthesis_file | awk -f $html_script > $tmp/content-letters.html || {
		echo Error: Failed to render TSV into HTML >[1=2]
		exit 1
	}
	rm -f $target
	for(i in $t/header.html $t/content-intro.html $tmp/content-letters.html $tmp/content-prompt.html $t/footer.html) {
		cat $i >> $target || {
			echo Error: Failed to append template $i to $target >[1=2]
			exit 1
		}
	}

# Clean up built artifacts
clean:V:
	rm -rf $tmp dist/* $p_bin

# Install dependencies
deps:V:
	# go get -u ./...

# Run tests
test:V:
	# go test ./...
