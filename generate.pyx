r"""

This script carries out all operations necessary to generate minimally
3-connected graphs with a prism minor that involve:

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

"""

import argparse
import logging as log
import sys
import os.path
import json
import csv
import gzip
from collections import namedtuple, defaultdict
from m3c.bx_graph import graph_from_root, graph_from_bytes_list
from m3c.generators import *
from m3c.nauty_cert import gen_cert
from m3c.lean_collection import graph_filename, read_graph_file, GraphFileWriter
from m3c.cycles import graph_cyc_from_bytes_list, find_cycles, BXGraphCyc


Instruction = namedtuple("Instruction", ["source", "alg", "dest"])


class Dummy(object):
    def __init__(self):
        pass

    def __enter__(self):
        return self

    def write(self, s):
        pass

    def __exit__(self, type, value, traceback):
        pass


def print_instruction(self):
    return "Instruction(source={}, alg={}, dest={})".format(self.source, self.alg.__name__, self.dest)


Instruction.__str__ = print_instruction

#     Instruction(source="B", alg=e6, dest="C1"),

EX_INSTRUCTIONS = [
    Instruction(source="B", alg=e2, dest="C"),
    Instruction(source="A0", alg=e1, dest="B"),
    Instruction(source="A1", alg=e1, dest="B"),
    Instruction(source="A2", alg=e1, dest="B"),
    Instruction(source="A3", alg=e1, dest="B")
]

CE_INSTRUCTIONS = [
    Instruction(source="B", alg=c1, dest="A1"),
    Instruction(source="A1", alg=c2, dest="A2"),
    Instruction(source="C", alg=c3, dest="A3")
]

GENERATORS = dict([(f.__name__, f) for f in GENERATOR_FTNS])

#  The only graphs we count or save are those that are used as a source -
#  others are just for eliminating graphs that are not minimally 3-connected

TYPES_TO_SAVE = set((inst.source for inst in EX_INSTRUCTIONS)) | set((inst.source for inst in CE_INSTRUCTIONS))


def read_instructions(fname):
    with open(fname) as f:
        reader = csv.reader(f)
        recs = list(reader)

    ex_instructions = list()
    ce_instructions = list()
    i = 0
    if recs[0][0] not in {"ex", "ce"}:
        i = 1
    for rec in recs[i:]:
        if rec[0] == "ex":
            ex_instructions.append(Instruction(source=rec[1], alg=GENERATORS[rec[2]], dest=rec[3]))
        elif rec[0] == "ce":
            ce_instructions.append(Instruction(source=rec[1], alg=GENERATORS[rec[2]], dest=rec[3]))
    return ex_instructions, ce_instructions


def open_graph_output_file(graph_type, filename, types_to_save):
    if graph_type in types_to_save:
        return gzip.open(filename, "at")
    return Dummy()


def _existing_file(s):
    if os.path.exists(s):
        return s
    raise ValueError("File {s} does not exist.".format(s=s))


def _parse_command_line():
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--root-name", dest="root_name", default="pr", help="Name of root graph")
    parser.add_argument("-f", "--root-filename", dest="root_fname", type=_existing_file, default="root.json", help="Root filename")
    parser.add_argument("-i", "--instructions-filename", dest="inst_fname", default=None, help="If specified, read instructions from this (CSV) file")
    parser.add_argument("m", type=int, help="Number of edges")
    parser.add_argument("n", type=int, help="Number of vertices")

    args = parser.parse_args()
    return args


def _root_graph(fname, root_name, use_cycles):
    with open(fname) as f:
        roots = json.load(f)
    adj = roots[root_name]
    bg = graph_from_root(root_name, adj)

    if use_cycles:
        cycles = find_cycles(adj)
        bg = BXGraphCyc.from_bxgraph(bg, cycles)

    return bg


def generate_graphs(source, inst, dest):
    log.info("...applying instruction %s...", str(inst))
    nadded = 0
    ng = 0
    for g in source:
        for ge in inst.alg(g):
            cert = gen_cert(ge)
            nadded += dest.add_graph(ge, cert)
            ng += 1
            if ng % 100 == 0:
                log.info("...ng=%d, nadded=%d...", ng, nadded)
    log.info("...done. ng=%d, nadded=%d", ng, nadded)
    return nadded


def main(args):

    m = args.m
    n = args.n

    if args.inst_fname is None:
        log.info("Using default instructions")
        ex_instructions = EX_INSTRUCTIONS
        ce_instructions = CE_INSTRUCTIONS
        types_to_save = TYPES_TO_SAVE
    else:
        log.info("Loading instructions from %s...", args.inst_fname)
        ex_instructions, ce_instructions = read_instructions(args.inst_fname)
        types_to_save = set([inst.source for inst in ex_instructions]) | set([inst.source for inst in ce_instructions])
        log.info("...done. len(ex_instructions) = %d, len(ce_instructions) = %d", len(ex_instructions), len(ce_instructions))

    #
    # determine which function to use to read graphs from JSON - if
    # any generators require cycles, then use the function that expects
    # them and produces BXGraphCyc instances
    #
    use_cycles = False
    if any([inst.alg in CYCLES_FTNS for inst in ex_instructions]) or any([inst.alg in CYCLES_FTNS for inst in ce_instructions]):
        read_graph_ftn = graph_cyc_from_bytes_list
        use_cycles = True
    else:
        read_graph_ftn = graph_from_bytes_list

    counts = defaultdict(int)

    log.info("Loading root graph...")
    rg = _root_graph(args.root_fname, args.root_name, use_cycles)
    log.info("...done. Root graph has %d vertices and %d edges", rg.size, rg.nedge)

    log.info("Generating extensions...")
    writer = GraphFileWriter()

    for inst in ex_instructions:
        dest_fname = graph_filename(n, m, inst.dest)
        log.info("...writing output for instruction %s to %s...", str(inst), dest_fname)
        with open_graph_output_file(inst.dest, dest_fname, types_to_save) as fo:
            writer.set_file(fo)
            if inst.source == "A0" and n == rg.size and m - 1 == rg.nedge:
                counts[inst.dest] += generate_graphs([rg], inst, writer)
            else:
                input_fname = graph_filename(n, m - 1, inst.source)
                if os.path.exists(input_fname):
                    with gzip.open(input_fname, "rt") as f:
                        counts[inst.dest] += generate_graphs(read_graph_file(f, read_graph_ftn), inst, writer)
                else:
                    log.info("...no input file %s for instruction %s, skipping...", input_fname, str(inst))
        writer.set_file(None)
    log.info("...extensions done.")

    log.info("Generating coextensions...")
    for inst in ce_instructions:
        dest_fname = graph_filename(n, m, inst.dest)
        log.info("...writing output for instruction %s to %s...", str(inst), dest_fname)
        with open_graph_output_file(inst.dest, dest_fname, types_to_save) as fo:
            writer.set_file(fo)
            if inst.source == "A0" and n - 1 == rg.size and m - 1 == rg.nedge:
                counts[inst.dest] += generate_graphs([rg], inst, writer)
            else:
                input_fname = graph_filename(n - 1, m - 1, inst.source)
                if os.path.exists(input_fname):
                    with gzip.open(input_fname, "rt") as f:
                        counts[inst.dest] += generate_graphs(read_graph_file(f, read_graph_ftn), inst, writer)
                else:
                    log.info("...no input file %s for instruction %s, skipping...", input_fname, str(inst))
        writer.set_file(None)
    log.info("...coextensions done.")

    summary_fname = "summary.csv"
    header = None
    if not(os.path.isfile(summary_fname)):
        header = ["nvert", "nedge", "type", "count"]
    with open(summary_fname, "a", newline="") as f:
        writer = csv.writer(f)
        if header is not None:
            writer.writerow(header)
        for key, count in counts.items():
            writer.writerow([n, m, key, count])

    tot = sum(counts.values())

    print(tot)


if __name__ == "__main__":
    args = _parse_command_line()
    log.basicConfig(level=log.INFO, format="%(levelname)s:%(asctime)s %(message)s", filename="m3c-{n:02d}-{m:02d}.log".format(m=args.m, n=args.n))
    log.info("Command line: " + " ".join(sys.argv))
    main(args)
