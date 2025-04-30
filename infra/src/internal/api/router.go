package api

import (
    "net/http"
    "github.com/gorilla/mux"
)

func NewRouter() *mux.Router {
    r := mux.NewRouter()
    r.HandleFunc("/restart/{service}", RestartService).Methods("POST")
    r.HandleFunc("/reload", ReloadAll).Methods("POST")
    r.HandleFunc("/logs/{service}", StreamLogs).Methods("GET")
    r.HandleFunc("/status", StackStatus).Methods("GET")
    return r
}