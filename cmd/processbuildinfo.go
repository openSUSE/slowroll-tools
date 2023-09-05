package main

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	scoreMapPath       = "out/scoremap.json"
	pkgMapSrcBinPath   = "out/pkgmapsrcbin"
	pkgMapSrcDepPath   = "out/pkgmapsrcdep"
	pkgMapDepCountPath = "out/pkgmapdepcount"
)

func main() {
	fmt.Println("Loading data from files...")

	pkgMapSrcBin := make(map[string][]string)

	err := loadFromJsonFile(pkgMapSrcBinPath, &pkgMapSrcBin)
	if err != nil {
		panic(err)
	}

	pkgMapSrcDep := make(map[string][]string)

	err = loadFromJsonFile(pkgMapSrcDepPath, &pkgMapSrcDep)
	if err != nil {
		panic(err)
	}

	totDeps := len(pkgMapSrcDep)
	fmt.Print("Analyzing ", totDeps, " dependencies...")

	dotSep := totDeps / 70
	i := 0
	dependencyMap := make(map[string][]string)
	for pkg, binaries := range pkgMapSrcBin {
		deps := pkgMapSrcDep[pkg]

		for _, dep := range deps {
			for _, sub := range binaries {

				if dependencyMap[dep] == nil {
					dependencyMap[dep] = make([]string, 0)
				}
				dependencyMap[dep] = append(dependencyMap[dep], sub)
			}
		}

		i++
		if i%dotSep == 0 {
			fmt.Print(".")
		}
	}
	fmt.Println()

	dependencyCountMap := make(map[string]int)
	for pkg, deps := range dependencyMap {
		dependencyCountMap[pkg] = len(deps)
	}

	err = saveToJsonFile(pkgMapDepCountPath, dependencyCountMap)
	if err != nil {
		panic(err)
	}

	// find the max number of dependencies for a package
	maxDeps := getMaxDependencies(dependencyCountMap)

	// score based on number of dependencies (normalized)
	scoreMap := make(map[string]float64)
	leafPackages := make([]string, 0)
	rootPackages := make([]string, 0)

	for pkg, deps := range dependencyCountMap {
		// normalize
		scoreMap[pkg] = float64(deps) / float64(maxDeps)

		// find leaf and root packages
		if scoreMap[pkg] == 1 {
			rootPackages = append(rootPackages, pkg)
		} else if scoreMap[pkg] == 0 {
			leafPackages = append(leafPackages, pkg)
		}
	}

	fmt.Println("Root packages:", rootPackages)
	fmt.Println("Leaf packages:", leafPackages)

	err = saveToJsonFile(scoreMapPath, scoreMap)
	if err != nil {
		panic(err)
	}

	fmt.Println("Saved scoremap to", scoreMapPath)
}

func getMaxDependencies(depCountMap map[string]int) int {
	maxDeps := 0
	for _, deps := range depCountMap {
		if deps > maxDeps {
			maxDeps = deps
		}
	}
	return maxDeps
}

func saveToJsonFile(filename string, v any) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}

	enc := json.NewEncoder(file)
	enc.SetIndent("", "  ")
	err = enc.Encode(v)
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
