package main

import (
    "log"
    "net/http"
    "cdaprod.dev/infra-node/internal/api"
)

func main() {
    r := api.NewRouter()
    log.Println("[infra-node] Listening on :8080")
    if err := http.ListenAndServe(":8080", r); err != nil {
        log.Fatal(err)
    }
}