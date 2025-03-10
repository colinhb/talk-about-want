package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"github.com/colinhb/talk-about-want/prompter"
)

// escapeTabs converts tab characters to the '\t' escape sequence
func escapeTabs(str string) string {
	return strings.ReplaceAll(str, "\t", "\\t")
}

func main() {
	// Define CLI flags for configuration
	pFile := flag.String("p", "", "Path to file containing the prompt template")
	apiKey := flag.String("k", "", "Anthropic API key")
	maxWorkers := flag.Int("w", 1, "Maximum number of concurrent workers")
	sleepDuration := flag.Int("s", 0, "Sleep duration in milliseconds between API calls")
	fileMode := flag.Bool("f", false, "Treat inputs as file paths (default is to treat as raw strings)")
	flag.Parse()

	// Validate required flags
	if *pFile == "" {
		fmt.Println("Please provide a prompt template file using the -p flag")
		os.Exit(1)
	}

	if *apiKey == "" {
		fmt.Println("Please provide an Anthropic API key using the -k flag")
		os.Exit(1)
	}

	// Load and parse the template file
	b, err := os.ReadFile(*pFile)
	if err != nil {
		fmt.Printf("error reading prompt template file: %v", err)
		os.Exit(1)
	}
	tmpl, err := template.New("prompt").Parse(string(b))
	if err != nil {
		fmt.Printf("error parsing template: %v", err)
		os.Exit(1)
	}

	// Initialize the Anthropic API client
	client := prompter.NewClient(*apiKey)

	// Set input processing mode based on flags
	inputMode := prompter.InputModeString
	if *fileMode {
		inputMode = prompter.InputModeFile
	}

	// Create configuration for the prompter
	config := &prompter.Config{
		Tmpl:          tmpl,
		Client:        client,
		MaxWorkers:    *maxWorkers,
		SleepDuration: time.Duration(*sleepDuration) * time.Millisecond,
		InputMode:     inputMode,
	}

	// Setup input stream from stdin
	inputs := prompter.ReadInput()

	// Process inputs through worker pool and collect results
	results := prompter.ProcessInput(inputs, config)

	// Output results in tab-separated lines: input output
	for r := range results {
		displayInput := r.Input
		if inputMode == prompter.InputModeFile {
			displayInput = filepath.Base(r.Input)
		}
		fmt.Printf("%s\t%s\n", escapeTabs(displayInput), escapeTabs(r.Output))
	}
}
