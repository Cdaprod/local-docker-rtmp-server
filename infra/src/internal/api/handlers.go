package api

import (
    "fmt"
    "io"
    "net/http"
    "os/exec"
    "github.com/gorilla/mux"
)

func RestartService(w http.ResponseWriter, r *http.Request) {
    service := mux.Vars(r)["service"]
    out, err := exec.Command("docker", "restart", service).CombinedOutput()
    if err != nil {
        http.Error(w, string(out), 500)
        return
    }
    fmt.Fprint(w, string(out))
}

func ReloadAll(w http.ResponseWriter, r *http.Request) {
    out, err := exec.Command("/usr/local/bin/reload-all.sh").CombinedOutput()
    if err != nil {
        http.Error(w, string(out), 500)
        return
    }
    fmt.Fprint(w, string(out))
}

func StreamLogs(w http.ResponseWriter, r *http.Request) {
    service := mux.Vars(r)["service"]
    cmd := exec.Command("docker", "logs", "-f", service)
    stdout, _ := cmd.StdoutPipe()
    if err := cmd.Start(); err != nil {
        http.Error(w, "Failed to start log stream", 500)
        return
    }
    io.Copy(w, stdout)
}

func StackStatus(w http.ResponseWriter, r *http.Request) {
    out, err := exec.Command("docker", "ps").CombinedOutput()
    if err != nil {
        http.Error(w, string(out), 500)
        return
    }
    fmt.Fprint(w, string(out))
}