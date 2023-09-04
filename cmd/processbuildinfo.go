package main

import (
	"encoding/json"
	"fmt"
	"log"

	"os"

	"github.com/schollz/progressbar/v3"
)

var (
	pkgMapSrcBin map[string][]string
	pkgMapSrcDep map[string][]string
)

func main() {
	fmt.Println("Loading data from files...")

	err := loadFromJsonFile("out/pkgmapsrcbin", &pkgMapSrcBin)
	if err != nil {
		log.Fatal(err)
	}

	err = loadFromJsonFile("out/pkgmapsrcdep", &pkgMapSrcDep)
	if err != nil {
		log.Fatal(err)
	}

	bar := progressbar.NewOptions(
		len(pkgMapSrcBin),
		progressbar.OptionSetDescription("Calculating dependencies..."),
	)
	dependencyMap := make(map[string][]string)
	for pkg, binaries := range pkgMapSrcBin {

		deps := pkgMapSrcDep[pkg]
		bar.Add(1)

		for _, dep := range deps {
			for _, sub := range binaries {

				if dependencyMap[dep] == nil {
					dependencyMap[dep] = make([]string, 0)
				}

				dependencyMap[dep] = append(dependencyMap[dep], sub)
			}
		}
	}
	fmt.Println()

	dependencyCountMap := make(map[string]int)
	for pkg, deps := range dependencyMap {
		dependencyCountMap[pkg] = len(deps)
	}

	err = saveToJsonFile("out/pkgmapdepcount", dependencyCountMap)
	if err != nil {
		log.Fatal(err)
	}

	// find the max number of dependencies for a package
	maxDeps := 0
	for _, deps := range dependencyCountMap {
		if deps > maxDeps {
			maxDeps = deps
		}
	}

	// score based on number of dependencies (normalized)
	scoreMap := make(map[string]float64)
	leafPackages := make([]string, 0)
	rootPackages := make([]string, 0)

	for pkg, deps := range dependencyCountMap {
		scoreMap[pkg] = float64(deps) / float64(maxDeps)
		if scoreMap[pkg] == 1 {
			rootPackages = append(rootPackages, pkg)
		} else if scoreMap[pkg] == 0 {
			leafPackages = append(leafPackages, pkg)
		}
	}

	fmt.Println("Root packages:", rootPackages)
	fmt.Println("Leaf packages:", leafPackages)

	err = saveToJsonFile("out/scoremap.json", scoreMap)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Saved scoremap to out/scoremap.json")

}

func saveToJsonFile(filename string, v any) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}

	err = json.NewEncoder(file).Encode(v)
	if err != nil {
		return err
	}

	err = file.Close()
	return err
}

func loadFromJsonFile(filename string, v any) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}

	err = json.NewDecoder(file).Decode(v)
	if err != nil {
		return err
	}

	err = file.Close()
	return err
}
