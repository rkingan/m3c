r"""

Graph collection routines designed to minimize the memory footprint of the
program. Includes routines to load graphs from an input file and produce them
with a generator, and routines to check graph signatures against previously
generated graphs, and output novel graphs to an output file.

"""
import json


def graph_filename(nvert, nedge, tail):
    return "m3c-{nvert:02d}-{nedge:02d}-{tail}.txt.gz".format(nvert=nvert, nedge=nedge, tail=tail.strip())


def read_graph_file(f, read_ftn):
    for line in f:
        sp = line.strip()
        if len(sp) > 0:
            yield read_ftn(json.loads(sp))


class GraphFileWriter(object):
    __slots__ = ["_certs", "_fp"]

    def __init__(self):
        self._certs = set()
        self._fp = None

    def set_file(self, f):
        self._fp = f

    def add_graph(self, g, cert):
        assert self._fp is not None, "File pointer must be set before adding graphs"

        if cert not in self._certs:
            s = json.dumps(g.to_bytes_list())
            self._fp.write(s + "\n")
            self._certs.add(cert)
            return 1
        return 0

    def __len__(self):
        return len(self._certs)
