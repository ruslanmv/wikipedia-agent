# From Zero to Hero: Building Your First Go AI Agent – a Wikipedia Microservice for the MCP Gateway

> *“Give me a lever long enough and a fulcrum on which to place it, and I shall move the world.”*
> *— Archimedes (and, today, every AI agent developer)*

LangChain, AutoGPT, and other “AI agents” feel like magic because they wield **tools**—micro-services that reach out and touch the real world for them. In this hands-on guide you’ll create such a tool from an **empty folder** all the way to a **container-ready micro-service** the Model Context Protocol (MCP) Gateway can call. Our agent’s super-power:

*Send it a topic ⇒ get back the first-paragraph summary from Wikipedia.*

No prior micro-service experience required; if you can read basic Go, you can follow along. Ready? Let’s turn zeroes into heroes. 🚀

---

## 1. Prerequisites

| What               | Why                                 | Check-Command      |
| ------------------ | ----------------------------------- | ------------------ |
| **Go 1.21+**       | We’ll compile a tiny static binary. | `go version`       |
| **Docker**         | To build & run the final container. | `docker --version` |
| **A code editor**  | VS Code, GoLand, or Vim—your call.  | –                  |
| **A curious mind** | You bring this one.                 | ✅                  |

---

## 2. Step 1 – Project Setup

```bash
# 1 ➜  create a workspace folder
mkdir wikipedia-agent && cd wikipedia-agent

# 2 ➜  initialise a Go module
go mod init github.com/ruslanmv/wikipedia-agent
```

*What you just did*

* `mkdir … && cd …` – a clean slate keeps vendor clutter away from other projects.
* `go mod init` – tells Go **“this is a module named `github.com/<you>/wikipedia-agent`.”**

  * Adds a `go.mod` file (dependency manifest).
  * Future `go get` calls will append dependencies right there.



### Step 2 – The Skeleton Web Server

Create **`main.go`**:

```go
package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    // 1️⃣ route /health for quick container probes
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprint(w, "ok")
    })

    // 2️⃣ start the server
    fmt.Println("Wikipedia Agent listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Run it:

```bash
go run .
```

In another terminal:

```bash
curl localhost:8080/health
# → ok
```

First victory—your agent speaks HTTP.

### Step 3 – Gaining a Super-Power (the Wikipedia Client)

Why re-invent wheels? We’ll lean on [**github.com/trietmn/go-wiki**](https://pkg.go.dev/github.com/trietmn/go-wiki) – a thin wrapper over the MediaWiki API.

```bash
go get github.com/trietmn/go-wiki
```

Behind the scenes Go:

1.  Downloads the source.
2.  Pins the exact version in `go.mod` & `go.sum`.

### Step 4 & 5 – Writing the Brains and Wiring It Up

Now, let's put all the pieces together. We will add the Wikipedia logic and the request handler that uses it.

Replace the entire content of your **`main.go`** with the following complete and final code. This version includes the Wikipedia fetching logic, the `/lookup` handler, and all the necessary imports (`io` included).

```go
package main

import (
	"fmt"
	"io" // <-- Was missing
	"log"
	"net/http"

	wiki "github.com/trietmn/go-wiki"
)

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
		fmt.Fprint(w, "ok")
	})

	// Route for the Wikipedia lookup functionality
	http.HandleFunc("/lookup", lookupHandler) // <-- Was missing

	// Start the server
	fmt.Println("Wikipedia Agent listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

### Step 6 – End-to-End Test

Now that the code is complete, run the server again:

```bash
go run .      # ⏳ keep it running
```

Then, in another terminal, test the new endpoint:

```bash
curl -X POST -d "General relativity" http://localhost:8080/lookup
```

Expected output (truncated):

```
General relativity (GR), also known as the general theory of relativity …
```

Mission accomplished: our microservice delivers knowledge\! 🎉

## 8. Step 7 – From *Zero* to **Hero**: Dockerizing

Create **`Dockerfile`** in the project root:

```Dockerfile
# --- builder stage -----------------------------------------------------------
# Use a Go version that matches or exceeds the one in go.mod (>=1.24.4)
FROM golang:1.24.4 AS builder

# Set the working directory inside the container
WORKDIR /src

# Copy go.mod and go.sum files first to leverage layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the Go application into a static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o wikipedia-agent .

# --- final stage -------------------------------------------------------------
# Use a minimal, non-root distroless image
FROM gcr.io/distroless/static-debian12

# Run as non-root for security
USER nonroot:nonroot

# Copy the compiled binary from the builder
COPY --from=builder /src/wikipedia-agent /wikipedia-agent

# Expose the application port
EXPOSE 8080

# Default command
ENTRYPOINT ["/wikipedia-agent"]

```

Build & run:

```bash
docker build -t wikipedia-agent:latest .
docker run -p 8080:8080 wikipedia-agent:latest
```

Same `curl` test still works—only now your binary plus minimal runtime libraries make a **\~6 MiB** image you can ship anywhere.

---

## 9. (Bonus) Plugging into the MCP Gateway

Once you clone **`mcp-context-forge`** you can register the container:

1. Add a service to `docker-compose.yml` or to your Kubernetes Helm values:

```yaml
wikipedia-agent:
  image: wikipedia-agent:latest
  networks: [mcpnet]          # put it on the same network as the gateway
```

2. Start the stack (`docker compose up -d`); the gateway’s service discovery will list your new tool ID: **`fetch_wikipedia_summary`**.

3. Chain it in an AI workflow JSON:

```jsonc
[
  { "tool": "google-search-agent", "args": "AI hardware trends 2025" },
  { "tool": "fetch_wikipedia_summary", "args": "NVIDIA" }
]
```

The gateway fans out calls, merges content, and delivers enriched context to your LLM orchestrator. ✨

---

## 10. Conclusion & Next Steps

👏 **You did it!**

* From an empty folder to a running HTTP service.
* From plain code to a tiny, secure container.
* From a standalone app to a pluggable MCP tool.

### You learned to…

1. Spin up an HTTP server with the Go standard library.
2. Consume an external API via a community package.
3. Embrace Go’s explicit error handling.
4. Build lean, production-ready containers with multi-stage builds.

### Where to go from here?

* **Error resilience:** add retry/back-off logic for transient Wikipedia failures.
* **i18n:** accept a `lang` query parameter to fetch non-English summaries.
* **Streaming:** return sentences progressively using Server-Sent Events for faster perceived latency.
* **Observability:** plug in OpenTelemetry exporters for metrics & tracing (the MCP Gateway already understands them).

Your `wikipedia-agent` is now hero-ready—slot it behind the MCP Gateway and let your AI systems call upon centuries of collective knowledge on demand. Go build something extraordinary! 
