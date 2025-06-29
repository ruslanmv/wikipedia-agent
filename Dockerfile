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
