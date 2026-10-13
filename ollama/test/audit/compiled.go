package main

import (
    "debug/elf"
    "debug/gosym"
    "encoding/json"
    "crypto/sha256"
    "fmt"
    "os"
    "strings"
)

func main() {
    binary, err := elf.Open(os.Args[1])
    if err != nil { panic(err) }
    defer binary.Close()
    pclSection := binary.Section(".gopclntab")
    if pclSection == nil { pclSection = binary.Section(".data.rel.ro.gopclntab") }
    if pclSection == nil { panic("Missing Go function table") }
    pcl, err := pclSection.Data()
    if err != nil { panic(err) }
    symbols := []byte{}
    if section := binary.Section(".gosymtab"); section != nil {
        symbols, err = section.Data()
        if err != nil { panic(err) }
    }
    table, err := gosym.NewTable(symbols, gosym.NewLineTable(pcl, binary.Section(".text").Addr))
    if err != nil { panic(err) }
    matched := []string{}
    for _, function := range table.Funcs {
        if strings.HasPrefix(function.Name, "golang.org/x/crypto/openpgp") {
            matched = append(matched, function.Name)
        }
    }
    if len(table.Funcs) < 100 { panic("Incomplete function table") }
    raw, err := os.ReadFile(os.Args[1])
    if err != nil { panic(err) }
    json.NewEncoder(os.Stdout).Encode(map[string]any{
        "binary_sha256": fmt.Sprintf("%x", sha256.Sum256(raw)), "functions_examined": len(table.Funcs), "openpgp_functions": matched,
    })
}
