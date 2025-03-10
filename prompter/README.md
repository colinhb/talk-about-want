# Prompter

A simple command-line tool (and implementing package) for processing text through Anthropic's Claude API using customizable prompt templates.

**Note:** This is not a maintained tool. It was developed and used as part of a larger project.

## Architecture

Prompter follows a simple processing pipeline:

1. Read inputs from stdin (line by line)
2. Render each input into a prompt template (`{{.Input}}`)
3. Send prompts to Claude API in parallel (fan-out/fan-in)
4. Extract content in `<output>` tags from responses
5. Output results to stdout in TSV format (`input	output`)

Interested users should review `prompter.go` and `cmd/main.go` for implementation of the Go package and the command.

## Installation

```sh
go install github.com/colinhb/talk-about-want/prompter/cmd@latest
```

## Usage

Basic usage pattern:

```sh
cat inputs.txt | prompter -p template.txt -k YOUR_API_KEY [options]
```

### Required Flags

- `-p`: Path to prompt template file
- `-k`: Anthropic API key

### Optional Flags

- `-w`: Maximum number of concurrent workers (default: 1)
- `-s`: Per-worker sleep duration between API calls in milliseconds (default: 0)
- `-f`: Treat inputs as file paths instead of raw strings

### Template Format

Templates use Go's text/template syntax with an `{{.Input}}` variable where the input should be placed.

**The template must direct the Anthropic model to place its response in `<output>` tags. That is what is extracted, escaped, and returned to the user.**

Example template (`prompts/example.txt`):
```
You are a helpful assistant. Please analyze the following text:

{{.Input}}

Provide your analysis between <output> tags.

<output>Your analysis goes here</output>
```

The echo template (`prompts/echo.txt`) is helpful for testing.

## Examples

### Process strings from stdin

```sh
echo -e "Hello world\nGoodbye world" | prompter -p template.txt -k YOUR_API_KEY
```

Output:
```
Hello world	This is a simple greeting expressing positivity and friendliness.\n
Goodbye world	This is a farewell statement with a slightly melancholic tone.\n
```

### Process multiple files in parallel

```sh
find . -name "*.txt" | prompter -p template.txt -k YOUR_API_KEY -f -w 4
```

### Pipe to a file for later processing

```sh
cat inputs.txt | prompter -p template.txt -k YOUR_API_KEY > results.tsv
```

## Advanced Usage

### Rate limiting

The `-s` flag provides a coarse way to respect rate limts:

```sh
cat large_input.txt | prompter -p template.txt -k YOUR_API_KEY -w 3 -s 1000
```

### Processing TSV results

The output is tab-separated with escaped newlines (`\n`), making it easy to process with tools like `cut` or `awk`.

```sh
# Extract just the outputs
cat results.tsv | cut -f2 | tr '\\n' '\n' > outputs.txt
```
