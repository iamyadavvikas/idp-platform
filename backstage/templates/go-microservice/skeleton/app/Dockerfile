FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /{{name}} .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /{{name}} /{{name}}
EXPOSE 8080
ENTRYPOINT ["/{{name}}"]