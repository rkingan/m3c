# m3c - Python scripts for generating minimally 3-connected graphs

## Background

The script `generate.pyx` in this directory generates minimally 3-connected
graphs with a given cubic minor as a "root" graph; the default root graph is
the prism graph with 6 vertices and 9 edges. The code in this repository
implements the procedures documented in *Constructing Minimally 3-connected
graphs*, by Jo&atilde;o Paulo Costalonga, Robert Kingan and Sandra Kingan.
(link).

## Getting started

This program is written in Python version 3.6. It uses a few packages that
require special installation.

### Prerequisites

#### Cython

[Cython](https://cython.readthedocs.io/en/latest/src/quickstart/overview.html)
is an extension to Python programming language that causes source code to be
translated into optimized C/C++ code and compiled at runtime, which results
in faster program execution. Cython is the reason why all source code files
in this repository are named with .pyx, instead of .py, extensions.

#### pynauty

[pynauty](https://web.cs.dal.ca/~peter/software/pynauty/html/index.html) is a
Python/C extension module that allows the functionality in Brendan McKay and
Adolfo Piperno's [nauty](http://pallini.di.uniroma1.it/) system to be
accessed from Python. Note that in order to install pynauty, you must first
download and compile nauty itself. Installation instructions can be found
[here](https://web.cs.dal.ca/~peter/software/pynauty/html/install.html).

This program uses pynauty to generate graph
[certificates](https://web.cs.dal.ca/~peter/software/pynauty/html/guide.html#pynauty.certificate),
which are used in turn to eliminate newly generated graphs that are isomorphic
to graphs already generated.

#### IGraph

[igraph](https://igraph.org/) is a collection of network analysis tools; this
[program uses igraph's Python implementation to enumerate the simple paths
[between two vertices in a graph.

On some platforms, python-igraph may need to be compiled from source.
Installation instructions can be found on the [python-igraph home
page](https://igraph.org/python/).

### Running the program

Once you have the prerequisite packages installed, set your `PYTHONPATH`
environment variable to include this directory. The script `generate.pyx`
carries out all operations necessary to generate minimally 3-connected graphs
with a specific cubic minor that involve:

1. Creating n-vertex, m-edge graphs from n-vertex, (m-1)-edge graphs
2. Creating n-vertex, m-edge graphs from (n-1)-vertex, (m-1)-edge graphs

This script expects to find files containing source graphs for the operations
in the current directory, named according to the convention used in the script
when saving files. For instance, using the default set of instructions, if the
program were run to generate 11-vertex, 18-edge graphs, it would expect to
find the following files already present from previous runs:

* m3c-11-17-B.txt.gz
* m3c-11-17-A1.txt.gz
* m3c-11-17-A2.txt.gz
* m3c-11-17-A3.txt.gz
* m3c-10-17-B.txt.gz
* m3c-10-17-A1.txt.gz
* m3c-10-17-C.txt.gz

Source graphs of type A0 are implicitly assumed to be from the "root"
collection, and the default root graph is the prism graph.

For example, the following sequence of commands (on a Linux/Unix system) will
generate all minimally 3-connected 6-, 7- and 8-vertex graphs with a prism
minor (assuming that the environment variable `M3C` has been set to the top
directory of this repository and that the Python interpreter command is
`python`):

```bash
python $M3C/generate.pyx -r pr -f $M3C/root.json 10 6
python $M3C/generate.pyx -r pr -f $M3C/root.json 11 6
python $M3C/generate.pyx -r pr -f $M3C/root.json 12 6
python $M3C/generate.pyx -r pr -f $M3C/root.json 13 6
python $M3C/generate.pyx -r pr -f $M3C/root.json 11 7
python $M3C/generate.pyx -r pr -f $M3C/root.json 12 7
python $M3C/generate.pyx -r pr -f $M3C/root.json 13 7
python $M3C/generate.pyx -r pr -f $M3C/root.json 14 7
python $M3C/generate.pyx -r pr -f $M3C/root.json 15 7
python $M3C/generate.pyx -r pr -f $M3C/root.json 12 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 13 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 14 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 15 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 16 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 17 8
python $M3C/generate.pyx -r pr -f $M3C/root.json 18 8
```

The program will generate a log detailing its actions, and will output the
graphs in files named according to the current values of *n*, *m* and the type
of graph being generated. Note that only the graphs in the output files
containing "A1", "A2", or "A3" in the name are minimally 3-connected; the
graphs in the files with "B" and "C" in the name are intermediate graphs
generated as part of a multi-step procedure.

### TODO : how to convert the files to a better format


## Questions?

Contact Robert Kingan at robertkingan@gmail.com or Sandra Kingan at
skingan@brooklyn.cuny.edu.
