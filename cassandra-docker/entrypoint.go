package main

/*
 * Copyright 2015 Albert P. Tobey <atobey@datastax.com> @AlTobey
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * This program is a Docker entrypoint for Apache Cassandra.
 */

import (
	"bytes"
	"io"
	"io/ioutil"
	"log"
	"net"
	"os"
	"path"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/tobert/sprok"
	"gopkg.in/yaml.v2"
)

const ugid = 1337

type CassandraDockerConfig struct {
	SrcConfDir     string   // root path for assets to copy to the volume
	ConfDir        string   // conf directory
	DataDir        string   // data directory
	CommitLogDir   string   // cl directory
	LogDir         string   // log directory
	LibDir         string   // custom classpath directory
	SavedCachesDir string   // saved_caches directory
	CqlshDotDir    string   // ~/.cassandra
	CqlshConf      string   // ~/.cassandra/cqlshrc"
	CassandraYaml  string   // conf/cassandra.yaml
	SprokDir       string   // conf/sproks directory
	ExtraArgs      []string // args to be passed to child commands
	// Cassandra configuration items
	ClusterName      string // cluster_name in cassandra.yaml
	Seeds            string // seeds value for cassandra.yaml
	CassandraLogfile string // system.log
	DefaultIface     string // the default route interface
	DefaultIP        string // IP of the DefaultIface
	JmxPort          string // JMX port for nodetool
	HeapMB           int    // -Xmx / -Xms value in MB
	NewMB            int    // -Xmn value in MB
	Snitch           string // endpoint_snitch in cassandra.yaml
	DataCenter       string // dc in cassandra-rackdc.properties
	Rack             string // rack in cassandra-rackdc.properties 
}

func main() {
	cdc := CassandraDockerConfig{
		SrcConfDir:       "/src/conf",
		ConfDir:          "/data/conf",
		DataDir:          "/data/data",
		CommitLogDir:     "/data/commitlog",
		LogDir:           "/data/log",
		LibDir:           "/data/lib",
		SavedCachesDir:   "/data/saved_caches",
		CqlshDotDir:      "/data/.cassandra",
		CqlshConf:        "/data/.cassandra/cqlshrc",
		CassandraYaml:    "/data/conf/cassandra.yaml",
		SprokDir:         "/data/conf/sproks",
		ClusterName:      "Docker Cluster",
		Seeds:            "127.0.0.1",
		CassandraLogfile: "/data/log/system.log",
		DefaultIface:     "eth0",
		DefaultIP:        "127.0.0.1",
		JmxPort:          "7199",
		HeapMB:           1024,
		NewMB:            256,
		Snitch:           "SimpleSnitch",
		DataCenter:       "DC1",
		Rack:             "RAC1",
	}

	var command, sprokFile string
	var args []string
	var dcOrRackSet bool

	// extract the command, e.g. 'cassandra', 'nodetool' from os.Args
	// when not present it's assumed to be 'cassandra' even when arguments
	// are provided.
	if path.Base(os.Args[0]) != "cassandra-docker" {
		// handle symlink commands, e.g. ln -s /bin/cassandra-docker /bin/cqlsh
		command = path.Base(os.Args[0])
		args = os.Args[1:]
	} else if len(os.Args) == 1 {
		// no arguments: run cassandra
		command = "cassandra"
		args = []string{}
	} else if len(os.Args) > 1 {
		// when no command is provided, assume cassandra + flags
		// otherwise take the first argument as the command and check it below
		if strings.HasPrefix(os.Args[1], "-") {
			command = "cassandra"
			args = os.Args[1:]
		} else {
			command = os.Args[1]
			if len(os.Args) > 2 {
				args = os.Args[2:]
			} else {
				args = []string{}
			}
		}
	}

	// parse the subcommand and arguments to it
	switch command {
	case "cassandra":

		dcOrRackSet = topologySpecified(args)

		args, _, cdc.Seeds = extractArg(args, "seeds", "127.0.0.1")
		args, _, cdc.ClusterName = extractArg(args, "name", "Docker Cluster")
		args, _, cdc.HeapMB = extractIntArg(args, "heap", 1024)
		args, _, cdc.NewMB = extractIntArg(args, "new", 256)
		args, _, cdc.Snitch = extractArg(args, "snitch", "SimpleSnitch")
		args, _, cdc.DataCenter = extractArg(args, "dc", "DC1")
		args, _, cdc.Rack = extractArg(args, "rack", "RAC1")

		// if heap is set but newsize is not, recalculate at 25% of heap
		if cdc.HeapMB != 1024 && cdc.NewMB == 256 {
			cdc.NewMB = cdc.HeapMB / 4
		}

		// If dc or rack are set (and snitch is not), set snitch accordingly
		if (dcOrRackSet) && cdc.Snitch == "SimpleSnitch" {
			cdc.Snitch = "GossipingPropertyFileSnitch"
		}

		sprokFile = path.Join(cdc.SprokDir, "cassandra.yaml")
	case "cqlsh":
		sprokFile = path.Join(cdc.SprokDir, "cqlsh.yaml")
	case "nodetool":
		args, _, cdc.JmxPort = extractArg(args, "p", "7199")
		sprokFile = path.Join(cdc.SprokDir, "nodetool.yaml")
	case "cassandra-stress":
		sprokFile = path.Join(cdc.SprokDir, "cassandra-stress.yaml")
	default:
		log.Fatalf("invalid command '%s'", command)
	}

	// copy the remaining command-line args to cdc so templates can render
	cdc.ExtraArgs = args

	// bootstrap - find the default IP, make directories, copy files

	cdc.guessDefaultIface()
	if strings.EqualFold(cdc.Seeds, "127.0.0.1") {
		cdc.Seeds = cdc.DefaultIP
	}

	cdc.mkdirs()

	// copies files from src to data, running them through as templates
	// in the process. existing files are not overwritten
	cdc.tmplCopy()

	// load the sprok config
	fd, err := os.Open(sprokFile)
	if err != nil {
		log.Fatalf("error opening '%s' for read: %s\n", sprokFile, err)
	}

	// render the config template before unmarshaling
	// this allows sprok files to work across upgrades with smart use
	// of glob() to work around files with version numbers in them
	var data bytes.Buffer
	cdc.render(fd, &data)

	// configure the process from the yaml
	proc := sprok.NewProcess()
	err = yaml.Unmarshal(data.Bytes(), &proc)
	if err != nil {
		log.Fatalf("could not parse YAML in file '%s': %s\n", sprokFile, err)
	}

	// this is an actual execve(3p), this process is replaced with the new one
	proc.Exec()
}

func topologySpecified(args []string) bool {
	for _, arg := range args {
		if arg == "-dc" || arg == "-rack" {
			return true
		}
	}
	return false
}

func (cdc *CassandraDockerConfig) mkdirs() {
	mkdirAll(cdc.ConfDir)
	mkdirAll(cdc.DataDir)
	mkdirAll(cdc.CommitLogDir)
	mkdirAll(cdc.LogDir)
	mkdirAll(cdc.SavedCachesDir)
	mkdirAll(cdc.CqlshDotDir)
	mkdirAll(cdc.SprokDir)

	chownAll(cdc.DataDir)
	chownAll(cdc.CommitLogDir)
	chownAll(cdc.LogDir)
	chownAll(cdc.SavedCachesDir)
	chownAll(cdc.CqlshDotDir)
}

// tmplCopy reads all the files in cdc.SrcConfDir, treating them as text
// templates, then writes them to cdc.ConfDir. If a file exists in ConfDir
// it is not overwritten.
func (cdc *CassandraDockerConfig) tmplCopy() {
	walk := func(fromName string, fromFi os.FileInfo, err error) error {
		if err != nil {
			log.Fatalf("failed to find files in '%s': %s\n", cdc.SrcConfDir, err)
		}

		// only safe for same filesystem with no relative paths or symlinks
		toName := strings.Replace(fromName, cdc.SrcConfDir, cdc.ConfDir, 1)

		// don't overwrite existing files
		if exists(toName) {
			return nil
		// ignore dotfiles
		} else if strings.HasPrefix(path.Base(fromName), ".") {
			return nil
		// create directories
		} else if fromFi.IsDir() {
			if exists(toName) {
				return nil
			} else {
				mkdirAll(toName)
			}
		// render files
		} else if fromFi.Mode().IsRegular() {
			// don't render sprok files, only copy them
			// they will get rendered at run time
			if strings.HasSuffix(path.Dir(fromName), "sproks") {
				cp(fromName, toName)
			} else {
				cdc.renderFile(fromName, toName)
			}
		} else {
			log.Fatalf("unsupported file mode on file '%s'\n", fromName)
		}

		return nil
	}

	err := filepath.Walk(cdc.SrcConfDir, walk)
	if err != nil {
		log.Fatalf("tmplCopy() failed: %s\n", err)
	}

	// write out a cqlshrc so cqlsh works as expected
	if !exists(cdc.CqlshConf) {
		cdc.renderFile(path.Join(cdc.SrcConfDir, "cqlshrc"), cdc.CqlshConf)
	}
}

// renderFile renders one file to another using text/template
func (cdc *CassandraDockerConfig) renderFile(src, dest string) {
	in, err := os.Open(src)
	if err != nil {
		log.Fatalf("could not open '%s' for reading: %s\n", src, err)
	}
	defer in.Close()

	out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		log.Fatalf("could not open '%s' for write: %s\n", dest, err)
	}
	defer out.Close()

	cdc.render(in, out)
}

// render renders an io.Reader to an io.Writer using text/template
func (cdc *CassandraDockerConfig) render(in io.Reader, out io.Writer) {
	funcMap := template.FuncMap{
		"glob": Globber,
	}

	tdata, err := ioutil.ReadAll(in)
	if err != nil {
		log.Fatalf("template read failed: %s\n", err)
	}

	tmpl, err := template.New("whatever").Funcs(funcMap).Parse(string(tdata))
	if err != nil {
		log.Fatalf("template parsing failed: %s", err)
	}

	err = tmpl.Execute(out, cdc)
	if err != nil {
		log.Fatalf("template rendering failed: %s\n", err)
	}
}

// guessDefaultIface finds the *most likely* default route
// interface and sets the cdc.DefaultIP + cdc.DefaultIface values.
func (cdc *CassandraDockerConfig) guessDefaultIface() {
	ifaces, err := net.Interfaces()
	if err != nil {
		log.Fatalf("error while listing network interfaces: %s\n", err)
	}

	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 {
			continue // interface is down
		}
		if iface.Flags&net.FlagLoopback != 0 {
			continue // ignore loopback interface
		}

		addrs, err := iface.Addrs()
		if err != nil {
			log.Fatalf("error while examining network interface: %s\n", err)
		}

		// go with the first interface that is up, has an address,
		// and is not a loopback. This should cover most Docker setups.
		for _, addr := range addrs {
			switch v := addr.(type) {
			case *net.IPNet:
				// net.IP.To4 (as of Go 1.4) will return nil if v.IP is a full v6 address
				ip := v.IP.To4()
				if ip != nil {
					cdc.DefaultIface = iface.Name
					cdc.DefaultIP = ip.String()
					return
				}
			}
		}
	}
}

// Globber takes paths, performs a glob match, then returns
// all the results joined with the specified seperator.
func Globber(sep string, globs ...string) string {
	if len(globs) == 0 {
		log.Fatalf("Globber() requires at least one path.\n")
	}

	out := []string{}

	for _, glob := range globs {
		filenames, err := filepath.Glob(glob)
		if err != nil {
			log.Fatalf("file glob failed: %s\n", err)
		}

		for _, filename := range filenames {
			out = append(out, filename)
		}
	}

	return strings.Join(out, sep)
}

// exists returns boolean whether a path exists or not
func exists(name string) bool {
	_, err := os.Stat(name)
	if os.IsNotExist(err) {
		return false
	} else if err != nil {
		log.Fatalf("could not stat file '%s': %s\n", name, err)
	}

	return true
}

// mkdirAll creates a directory recursively, crashes the program on error.
func mkdirAll(name string) {
	err := os.MkdirAll(name, 0755)
	if err != nil {
		log.Fatalf("os.MkdirAll('%s') failed: %s\n", name, err)
	}
}

func chownAll(name string) {
	walk := func(fname string, fi os.FileInfo, err error) error {
		if err != nil {
			log.Fatalf("error during fs walk of '%s': %s\n", fname, err)

		}

		return os.Chown(fname, ugid, ugid)
	}

	err := filepath.Walk(name, walk)
	if err != nil {
		log.Fatalf("chownAll('%s') failed: %s\n", name, err)
	}
}

// cp copies a file, crashing the program on any errors
// It does not attempt to use rename.
func cp(from, to string) {
	in, err := os.Open(from)
	if err != nil {
		log.Fatalf("could not open '%s' for reading: %s\n", from, err)
	}
	defer in.Close()

	out, err := os.OpenFile(to, os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		log.Fatalf("could not open '%s' for writing: %s\n", to, err)
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	if err != nil {
		log.Fatalf("data copy failed for file '%s': %s\n", to, err)
	}
}
