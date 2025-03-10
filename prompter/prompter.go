package prompter

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os"
	"strings"
	"sync"
	"text/template"
	"time"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// InputMode defines how input strings should be interpreted
type InputMode int

const (
	// InputModeString treats inputs as text to be directly used in templates
	InputModeString InputMode = iota
	// InputModeFile treats inputs as file paths to be read from disk
	InputModeFile
)

// Result contains the output from processing an input with the Anthropic API
type Result struct {
	Input  string // Original input (string or file path)
	Output string // API response with newlines escaped
}

// Config contains all parameters needed for parallel processing of template-based API requests
type Config struct {
	Tmpl          *template.Template // Template to render prompts
	Client        *anthropic.Client  // Anthropic API client
	MaxWorkers    int                // Number of concurrent API callers
	SleepDuration time.Duration      // Sleep time between API calls for rate limiting
	InputMode     InputMode          // Whether inputs are raw strings or file paths
}

// NewClient creates and configures a new Anthropic API client
func NewClient(apiKey string) *anthropic.Client {
	return anthropic.NewClient(
		option.WithAPIKey(apiKey),
	)
}

// ReadInput reads lines from stdin and sends them to a channel until EOF
func ReadInput() <-chan string {
	inputs := make(chan string, 100)
	go func() {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			inputs <- scanner.Text()
		}
		close(inputs)
	}()
	return inputs
}

// ProcessInput distributes work across a pool of workers that process inputs and return results
func ProcessInput(inputs <-chan string, config *Config) <-chan Result {
	var wg sync.WaitGroup

	results := make(chan Result, config.MaxWorkers)

	for i := 0; i < config.MaxWorkers; i++ {
		wg.Add(1)
		go worker(inputs, results, config, &wg)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	return results
}

// worker processes inputs by rendering templates, calling the API, and formatting results
func worker(inputs <-chan string, results chan<- Result, config *Config, wg *sync.WaitGroup) {
	defer wg.Done()
	var newWorker bool = true
	for input := range inputs {

		var content string
		var err error

		// Give old workers a chance to sleep
		// (This is a coarse way to rate limit API calls)
		if !newWorker && config.SleepDuration > 0 {
			time.Sleep(config.SleepDuration)
		}

		content, err = maybeReadFile(input, config.InputMode)
		if err != nil {
			fmt.Printf("Error with input: %v\n", err)
			continue
		}

		prompt, err := renderPrompt(content, config.Tmpl)
		if err != nil {
			fmt.Printf("Error rendering prompt: %v\n", err)
			continue
		}

		text, err := getTextFromAPI(prompt, config.Client)
		if err != nil {
			fmt.Printf("Error processing with API: %v\n", err)
			continue
		}

		output, err := extractTag("output", text)
		if err != nil {
			fmt.Printf("Error extracting output: %v\n", err)
			continue
		}

		escaped := escapeNewlines(output)

		results <- Result{input, escaped}

		// Set newWorker to false after first iteration
		if newWorker {
			newWorker = false
		}
	}
}

// maybeReadFile returns either the input string or the contents of the file at that path
func maybeReadFile(input string, mode InputMode) (string, error) {
	var content string
	switch mode {
	case InputModeString:
		content = input
	case InputModeFile:
		fileContent, err := os.ReadFile(input)
		if err != nil {
			return "", fmt.Errorf("error reading file: %v", err)
		}
		content = string(fileContent)
	default:
		return "", fmt.Errorf("unimplemented input mode: %v", mode)
	}
	return content, nil
}

// renderPrompt applies the template to the content and returns the rendered result
func renderPrompt(content string, tmpl *template.Template) (string, error) {
	var buf bytes.Buffer
	data := struct{ Input string }{content}
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("error executing template: %v", err)
	}
	return buf.String(), nil
}

// getTextFromAPI sends the prompt to Anthropic and returns the model's response text
func getTextFromAPI(prompt string, client *anthropic.Client) (string, error) {
	ctx := context.TODO()
	msg, err := client.Messages.New(ctx, anthropic.MessageNewParams{
		Model:     anthropic.F(anthropic.ModelClaude3_7SonnetLatest),
		MaxTokens: anthropic.F(int64(1024)),
		Messages: anthropic.F([]anthropic.MessageParam{
			anthropic.NewUserMessage(anthropic.NewTextBlock(prompt)),
		}),
	})
	if err != nil {
		return "", fmt.Errorf("error from API call: %v", err)
	}
	var text string
	for _, block := range msg.Content {
		if block.Type == anthropic.ContentBlockTypeText {
			text += block.Text
		}
	}
	return text, nil
}

// extractTag returns content between <tag> and </tag> markers in the input string
func extractTag(tag, str string) (string, error) {
	start := fmt.Sprintf("<%s>", tag)
	end := fmt.Sprintf("</%s>", tag)

	startIdx := bytes.Index([]byte(str), []byte(start))
	if startIdx == -1 {
		return "", fmt.Errorf("no start found in string: %s", str)
	}
	startIdx += len(start)
	endIdx := bytes.Index([]byte(str[startIdx:]), []byte(end))
	if endIdx == -1 {
		return "", fmt.Errorf("no end found in string: %s", str)
	}
	out := str[startIdx : startIdx+endIdx]
	out = string(bytes.TrimSpace([]byte(out)))
	return out, nil
}

// escapeNewlines converts newline characters to the '\n' escape sequence
func escapeNewlines(str string) string {
	return strings.ReplaceAll(str, "\n", "\\n")
}
