package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	wiki "github.com/trietmn/go-wiki"
)

// appVersion is the application version, injected at build time by the Makefile.
var appVersion = "dev" // Default value if not built with Makefile

// fetchWikipediaSummary returns the first paragraph (the “extract”) for a topic.
func fetchWikipediaSummary(topic string) (string, error) {
	// 1. Get the page (lang -1 = default to EN)
	page, err := wiki.GetPage(topic, -1, false, false)
	if err != nil {
		return "", err // network / page not found error
	}

	// 2. Retrieve & return the summary
	summary, err := page.GetSummary()
	if err != nil {
		return "", err
	}
	return summary, nil
}

// lookupHandler reads a topic from a POST request, fetches the Wikipedia summary,
// and writes the summary back as the response.
func lookupHandler(w http.ResponseWriter, r *http.Request) {
	// Only allow POST for simplicity
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	// 1. Read the whole request body (the topic string)
	topicBytes, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "cannot read body", http.StatusBadRequest)
		return
	}
	topic := string(topicBytes)

	// 2. Call the brains to fetch the summary
	summary, err := fetchWikipediaSummary(topic)
	if err != nil {
		http.Error(w, fmt.Sprintf("lookup error: %v", err), http.StatusInternalServerError)
		return
	}

	// 3. Happy path: write the summary to the response
	fmt.Fprint(w, summary)
}

func main() {
	// Route for health checks
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	// Route for version info
	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		// Set the content type to application/json
		w.Header().Set("Content-Type", "application/json")
		// Create a map or struct for the response
		versionInfo := map[string]string{
			"name":    "wikipedia-agent",
			"version": appVersion,
		}
		// Encode the map to JSON and write it to the response
		json.NewEncoder(w).Encode(versionInfo)
	})

	// Route for the Wikipedia lookup functionality
	http.HandleFunc("/lookup", lookupHandler)

	// Start the server
	fmt.Printf("Wikipedia Agent v%s listening on :8080\n", appVersion)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
