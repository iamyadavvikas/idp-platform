FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /demo-app .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /demo-app /demo-app
EXPOSE 8080
ENTRYPOINT ["/demo-app"]
