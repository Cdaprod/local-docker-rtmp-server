# Initialize go.mod with by:

## Inside the Docker container or on the host machine

``` 
cd websocket-go
go mod init websocket-go
go mod tidy
go build -o obs-websocket-automation main.go
./obs-websocket-automation
``` 