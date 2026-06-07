# Stage 1: Builder
FROM golang:1.22.5-alpine AS builder

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /build

# No go.sum exists — only stdlib is used, no external deps
COPY go.mod ./

# Copy source and build
COPY . .
RUN go build -ldflags="-s -w" -o main .

# Stage 2: Minimal runtime image
FROM alpine:3.21

WORKDIR /app

# Install curl only for healthcheck
RUN apk add --no-cache curl

# Create non-root user for security
RUN adduser -D appuser

# Copy compiled binary from builder
COPY --from=builder /build/main .

# ✅ CRITICAL: Copy static files — needed at runtime for http.ServeFile()
COPY --from=builder /build/static ./static

RUN chmod +x main

USER appuser

# Port matches main.go: ListenAndServe("0.0.0.0:8080", nil)
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/home || exit 1

CMD ["./main"]