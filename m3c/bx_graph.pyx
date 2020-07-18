r"""

Representation of an undirected simple graph using an array of bytes for the
adjacency matrix, and also keeping track of the graph's history as a sequence
of operations applied to a "root" graph.

"""
from .bgx import bytes_from_int, int_from_bytes, BITS, FLAGS


def bytes_from_op_list(op_list):
    op_name = op_list[0]
    if op_name == "v":
        return bytes("v ", encoding="utf-8")
    elif op_name == "d":
        return bytes("d ", encoding="utf-8") + bytes_from_int(op_list[1]) + bytes_from_int(op_list[2])
    elif op_name == "e":
        return bytes("e ", encoding="utf-8") + bytes_from_int(op_list[1]) + bytes_from_int(op_list[2])
    raise ValueError("Invalid operation " + str(op_list))


def bytes_from_tx(tx):
    p1 = bytes((tx[0] + "  ")[0:2], encoding="utf-8")
    p2 = bytes_from_int(len(tx) - 1)
    result = p1 + p2
    for op_list in tx[1:]:
        result += bytes_from_op_list(op_list)
    return result


def bytes_from_hist(hist):
    root = hist[0]
    bb = bytes((root + "  ")[0: 2], encoding="utf-8")
    bb += bytes_from_int(len(hist) - 1)
    for tx in hist[1:]:
        bb += bytes_from_tx(tx)
    return bb


def op_list_from_bytes(b, ix):
    jx = ix
    op_name = bytes.decode(b[ix: ix + 2], encoding="utf-8").strip()
    jx += 2
    if op_name == "v":
        return [op_name], jx
    elif op_name == "e" or op_name == "d":
        i, jx = int_from_bytes(b, jx)
        j, jx = int_from_bytes(b, jx)
        return [op_name, i, j], jx
    raise ValueError("Invalid operation " + op_name)


def tx_from_bytes(b, ix):
    jx = ix
    tx_name = bytes.decode(b[ix: ix + 2], encoding="utf-8")
    jx += 2
    tx_len, jx = int_from_bytes(b, jx)
    ops = list()
    for i in range(tx_len):
        op, jx = op_list_from_bytes(b, jx)
        ops.append(op)
    return [tx_name] + ops, jx


def hist_from_bytes(bb):
    h_list = list()
    root = bytes.decode(bb[0: 2], encoding="utf-8")
    h_list.append(root)
    hlen, jx = int_from_bytes(bb, 2)
    for i in range(hlen):
        tx, jx = tx_from_bytes(bb, jx)
        h_list.append(tx)
    return h_list


class AddEdge(object):
    r"""

    Represents an edge addition

    """
    __slots__ = ["i", "j"]
    code = "e"

    def __init__(self, i, j):
        if i == j:
            raise ValueError("Cannot connect a vertex to itself")
        self.i = i
        self.j = j

    def __str__(self):
        return "e({i},{j})".format(i=self.i, j=self.j)

    def to_list(self):
        return [AddEdge.code, self.i, self.j]


class DelEdge(object):
    r"""

    Represents an edge deletion

    """
    __slots__ = ["i", "j"]
    code = "d"

    def __init__(self, i, j):
        self.i = i
        self.j = j

    def __str__(self):
        return "d({i},{j})".format(i=self.i, j=self.j)

    def to_list(self):
        return [DelEdge.code, self.i, self.j]


class _AddVertex(object):
    r"""

    Represents a vertex addition

    """
    code = "v"

    def __str__(self):
        return "v"

    def to_list(self):
        return [_AddVertex.code]


_ADD_VERTEX = _AddVertex()  # singleton - no specific instances are needed


def AddVertex():
    return _ADD_VERTEX


def op_from_list(op_list):
    if len(op_list) < 1:
        raise ValueError("Cannot build an operation from list {lr}".format(lr=repr(op_list)))

    if op_list[0] == "v":
        return AddVertex()
    elif op_list[0] == "e":
        if len(op_list) != 3 or not(type(op_list[1]) is int) or not(type(op_list[2]) is int):
            raise ValueError("Invalid list for edge addition {lr}".format(lr=repr(op_list)))
        return AddEdge(op_list[1], op_list[2])
    elif op_list[0] == "d":
        if len(op_list) != 3 or not(type(op_list[1]) is int) or not(type(op_list[2]) is int):
            raise ValueError("Invalid list for edge de;etion {lr}".format(lr=repr(op_list)))
        return DelEdge(op_list[1], op_list[2])

    raise ValueError("Cannot build an operation from list due to invalid code: {lr}".format(lr=repr(op_list)))


class Transformation(object):
    r"""

    Represents one stage in the history of operations that produced a graph;
    specifies the algorithm used and a list of the operations performed by the
    algorithm.

    """
    __slots__ = ["alg", "ops"]

    def __init__(self, alg, ops):
        self.alg = alg
        self.ops = ops

    def __str__(self):
        return "{alg}(".format(alg=self.alg) + ",".join([str(op) for op in self.ops]) + ")"

    def to_list(self):
        return [self.alg] + [op.to_list() for op in self.ops]


def transformation_from_list(e_list):
    if len(e_list) < 1:
        raise ValueError("Cannot build history element from empty list")

    if type(e_list[0]) is not str:
        raise ValueError("First item in history element list must be algorithm name")

    alg = e_list[0]
    ops = [op_from_list(x) for x in e_list[1:]]
    return Transformation(alg, ops)


class History(object):
    r"""

    Represents the history of operations used to build a graph, including the
    name of the "root" graph and the sequence of history elements describing
    the operations performed.

    """
    __slots__ = ["root", "elements"]

    def __init__(self, root, elements):
        self.root = root
        self.elements = elements

    def __str__(self):
        return self.root + "+" + "+".join([str(x) for x in self.elements])

    def to_list(self):
        return [self.root] + [x.to_list() for x in self.elements]

    def to_bytes(self):
        return bytes_from_hist(self.to_list())


def history_from_list(h_list):
    if len(h_list) < 1:
        raise ValueError("Cannot recreate history from empty list")

    if type(h_list[0]) is not str:
        raise ValueError("First element of history list must be a string")

    root = h_list[0]
    elements = [transformation_from_list(x) for x in h_list[1:]]
    return History(root, elements)


def history_from_bytes(bb):
    h_list = hist_from_bytes(bb)
    return history_from_list(h_list)


def _are_conn(b, n, i, j):
    if i < 0 or i >= n or j < 0 or j >= n:
        raise IndexError("{i} and {j} are invalid indices for graph of size {n}".format(i=i, j=j, n=n))
    if i == j:
        return False
    ii, jj = (i, j) if i > j else (j, i)
    bi = ((ii * (ii - 1)) >> 1) + jj
    return b[bi >> 3] & FLAGS[bi % 8] != 0


class BXGraph(object):
    r"""

    Represents a graph with a history and (binary-format) adjacency matrix.

    """
    __slots__ = ["history", "size", "badj", "nedge"]

    def __init__(self, history, size, badj):
        self.history = history
        self.size = size
        self.badj = badj
        self.nedge = self._nedge()

    def _nedge(self):
        n = 0
        for i in range(1, self.size):
            for j in range(i):
                if self.conn(i, j):
                    n += 1
        return n

    def conn(self, i, j):
        return _are_conn(self.badj, self.size, i, j)

    def __str__(self):
        return "BXGraph(history={h}, size={s}, badj(hex)={b})".format(h=str(self.history), s=self.size, b=self.badj.hex())

    def to_list(self):
        return [self.history.to_list(), self.size, self.badj.hex()]

    def to_bytes_list(self):
        return [self.history.to_bytes().hex(), self.size, self.badj.hex()]


def bytes_from_adj(adj):
    r"""

    Generates a byte array to store the contents of an adjacency matrix.

    """
    n = len(adj)
    ba = list()
    bi = 0
    k = 0
    for i in range(1, n):
        for j in range(i):
            if adj[i][j] == 1:
                bi += BITS[k]
            k += 1
            if k == 8:
                ba.append(bi)
                bi = 0
                k = 0
    if k > 0:
        ba.append(bi)
    return bytes(ba)


def adj_from_bytes(ba, n):
    r"""

    Restores an adjacency matrix from a byte array.

    """
    adj = [[0 for i in range(n)] for j in range(n)]
    for i in range(1, n):
        for j in range(i):
            if _are_conn(ba, n, i, j):
                adj[i][j] = 1
                adj[j][i] = 1
    return adj


def ext_adj_from_bytes(ba, n, n_ext=1):
    r"""

    Restores an adjacency matrix from a byte array, adding vertices if needed.

    """
    adj = [[0 for i in range(n + n_ext)] for j in range(n + n_ext)]
    for i in range(1, n):
        for j in range(i):
            if _are_conn(ba, n, i, j):
                adj[i][j] = 1
                adj[j][i] = 1
    return adj


def graph_from_root(root, adj):
    r"""

    Builds a BXGraph instance generated by selecting a root graph from a
    collection.

    """
    size = len(adj)
    badj = bytes_from_adj(adj)
    history = History(root, list())
    return BXGraph(history, size, badj)


def apply_transformation(graph, transformation):
    r"""

    Applies a transformation to a BXGraph to obtain a new graph. Extensions
    are done first to avoid repeated reallocations of memory.

    """
    n_ext = sum([1 if tx.code == "v" else 0 for tx in transformation.ops])
    adj = ext_adj_from_bytes(graph.badj, graph.size, n_ext)
    for op in transformation.ops:
        if op.code == "e":
            if adj[op.i][op.j] == 1:
                raise ValueError("Attempt to add edge ({i}, {j}) which is already present.".format(i=op.i, j=op.j))
            adj[op.i][op.j] = 1
            adj[op.j][op.i] = 1
        elif op.code == "d":
            if adj[op.i][op.j] == 0:
                raise ValueError("Attempt to delete edge ({i}, {j}) which is not present.".format(i=op.i, j=op.j))
            adj[op.i][op.j] = 0
            adj[op.j][op.i] = 0
    history = History(graph.history.root, graph.history.elements + [transformation])
    return BXGraph(history, graph.size + n_ext, bytes_from_adj(adj))


def graph_from_list(g_list):
    r"""

    Restores a BXGraph instance from a list.

    """
    if len(g_list) != 3:
        raise ValueError("BXGraph list representation must be of size 3")

    history = history_from_list(g_list[0])
    size = int(g_list[1])
    badj = bytes.fromhex(g_list[2])
    return BXGraph(history, size, badj)


def graph_elements_from_bytes_list(gb_list):
    hbytes = bytes.fromhex(gb_list[0])
    history = history_from_bytes(hbytes)
    size = int(gb_list[1])
    badj = bytes.fromhex(gb_list[2])
    return history, size, badj


def graph_from_bytes_list(gb_list):
    r"""

    Restores a BXGraph instance from a list where the history is encoded as an array of bytes

    """
    if len(gb_list) != 3:
        raise ValueError("BXGraph list representation must be of size 3")

    history, size, badj = graph_elements_from_bytes_list(gb_list)

    return BXGraph(history, size, badj)
