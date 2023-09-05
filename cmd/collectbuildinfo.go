package main

import (
	"fmt"
	gobs "github.com/VaiTon/gobs"
	"io"
	"os"
	"time"
)

const MaxConcurrentDownloads = 30

func main() {
	client := gobs.NewClient("https://api.opensuse.org", "VaiTon", "SykbC+2hQ>^4!JF")

	_ = os.Mkdir("buildinfo", 0755)

	fmt.Println("Downloading buildinfo for all packages in openSUSE:Factory...")
	packages, err := client.GetPackages("openSUSE:Factory")
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "Failed to get packages: %s\n", err)
	}

	fmt.Printf("Found %d packages in openSUSE:Factory\n", len(packages))

	ch := make(chan string)

	go func() {
		for i, pkg := range packages {
			go fetchPackage(client, pkg, ch)

			if i%MaxConcurrentDownloads == 0 {
				time.Sleep(1 * time.Second)
			}
		}
	}()

	counter := 0
	padding := len(fmt.Sprintf("%d", len(packages)))
	for pkg := range ch {
		counter++
		fmt.Printf("[%*d/%d] Downloaded buildinfo for '%s'\n", padding, counter, len(packages), pkg)
	}

	fmt.Println("Done!")
}

func fetchPackage(client *gobs.Client, pkg string, ch chan<- string) {
	info, err := client.GetRaw("/build/openSUSE:Factory/standard/x86_64/" + pkg + "/_buildinfo")
	if err != nil {
		panic(err)
	}

	buf, err := io.ReadAll(info)
	if err != nil {
		panic(err)
	}

	err = os.WriteFile("buildinfo/"+pkg+".xml", buf, 0644)
	if err != nil {
		panic(err)
	}

	ch <- pkg
}
