package main

import (
    "os"
    "fmt"
    "io/ioutil"
    "strings"
    "github.com/google/uuid"
    "path/filepath"
    "net/http"
    "encoding/xml"
)

func readFile (fileName string) string {

    bytes, err := ioutil.ReadFile(fileName)
    if err != nil {
        fmt.Println(err)
        return ""
    }

    return string(bytes)    
}

func zip(a1, a2 []string) []string {
    r := make([]string, 2*len(a1))
    for i, e := range a1 {
        r[i*2] = e
        r[i*2+1] = a2[i]
    }
    return r
}

func parseResponse(filePath string, altFilePath string, original []string, replacements []string) string {

    file := readFile(filePath)

    if file == "" {
        return strings.NewReplacer(zip(original, replacements)...).Replace(readFile(altFilePath))
    }
    
    return strings.NewReplacer(zip(original, replacements)...).Replace(file)

}

func GetEntryResponse(pwd string, VIN string, original []string, replacements []string) string {
    return parseResponse(
        filepath.Join(pwd,"response","GetEntry",VIN + ".xml"),
        filepath.Join(pwd,"response","GetEntry","unknownVIN.error.xml"),
        original, replacements)
}
func ProcessAliveTestResponse(pwd string, serviceName string, original []string, replacements []string) string {
    return parseResponse(
        filepath.Join(pwd,"response","ProcessAliveTest","default.xml"),
        filepath.Join(pwd,"response","notAuthorized.error.xml"),
        original, replacements)
}

type Envelope struct {
    XMLName xml.Name
    Header  Header
    Body    Body
}

type Header struct {
    XMLName  xml.Name   `xml:"Header"`
    To      string      `xml:"To"`
    Action  string      `xml:"Action"`
    MessageID string    `xml:"MessageID"`
}

type Body struct {
    XMLName  xml.Name   `xml:"Body"`
    ProcessAliveTest string `xml:"ProcessAliveTest"`
    GetEntry struct {
        VehicleRef struct {
            VIN string  `xml:"VIN"`
        }
    }
}

func main() {

    pwd, _ := os.Getwd()
    Hostname, _ := os.Hostname()
    ProviderName := "MOCK-GSB-Proxy"
    Version := "0.5.0"
    Vendor := "Volkswagen AG"

    http.HandleFunc("/services", func(w http.ResponseWriter, r *http.Request) {
        if r.Method != http.MethodPost {
            return
        }

        // Read body
        b, err1 := ioutil.ReadAll(r.Body)
        defer r.Body.Close()
        if err1 != nil {
            http.Error(w, err1.Error(), 500)
            return
        }

        request := &Envelope{}
        err2 := xml.Unmarshal(b, request)
        if err2 != nil {
            http.Error(w, err2.Error(), 500)
            return
        }

        if strings.Contains(request.Header.Action, "ProcessAliveTest") {

            ServiceName := request.Header.To[5:strings.LastIndex(request.Header.To, "/")]
            ServiceName = ServiceName[strings.LastIndex(ServiceName, "/")+1:]

            fmt.Fprintf(w, 
                ProcessAliveTestResponse(
                    pwd,
                    request.Body.GetEntry.VehicleRef.VIN, 
                    []string{
                        "@@MessageID@@",
                        "@@Action@@", 
                        "@@RelatesTo@@",
                        "@@To@@",
                        "@@Namespace@@",
                        "@@Hostname@@",
                        "@@ProviderName@@",
                        "@@Version@@",
                        "@@Vendor@@",
                        "@@ServiceName@@"}, 
                    []string{
                        "urn:uuid:" + uuid.New().String(),
                        request.Header.Action, 
                        request.Header.MessageID,
                        request.Header.To,
                        "http://xmldefs." + request.Header.To[5:],
                        Hostname,
                        ProviderName,
                        Version,
                        Vendor,
                        ServiceName}))

        } else if strings.Contains(request.Header.Action, "VehicleLifecycleServicePortType/GetEntry") {

            fmt.Fprintf(w, 
                GetEntryResponse(
                    pwd,
                    request.Body.GetEntry.VehicleRef.VIN, 
                    []string{
                        "@@MessageID@@", 
                        "@@RelatesTo@@",
                        "@@VIN@@"}, 
                    []string{
                        "urn:uuid:" + uuid.New().String(), 
                        request.Header.MessageID,
                        request.Body.GetEntry.VehicleRef.VIN}))

        } else {

            original := []string{
                "@@MessageID@@", 
                "@@Action@@",
                "@@RelatesTo@@",
                "@@To@@"}

            replacements := []string{
                "urn:uuid:" + uuid.New().String(), 
                request.Header.Action,
                request.Header.MessageID,
                request.Header.To}

            fmt.Fprintf(w, 
                parseResponse(filepath.Join(pwd,"response","notAuthorized.error.xml"), "", original, replacements))

        }

    })

    http.ListenAndServe(":8080", nil)

}
