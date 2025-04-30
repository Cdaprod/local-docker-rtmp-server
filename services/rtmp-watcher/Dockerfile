FROM golang:1.21-alpine

WORKDIR /app
COPY . .

RUN go build -o watcher main.go

EXPOSE 1935
CMD ["/app/watcher"]