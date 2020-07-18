r"""

Functions for managing the list of cycles of a graph, including converting
lists to/from binary representations, and identifying changes in cycles when
graphs are modified. Uses igraph for generation of all simple paths between
two vertices.

"""
from .bgx import bytes_from_int, int_from_bytes
from .bx_graph import BXGraph, graph_elements_from_bytes_list, adj_from_bytes
import igraph


def _arg_min(item_list):
    mv = None
    mi = None
    for i in range(len(item_list)):
        if mv is None or item_list[i] < mv:
            mv = item_list[i]
            mi = i
    return mi


def _arrange_cycle(cv):
    i = _arg_min(cv)
    n = len(cv)
    d = 1
    if cv[(i - 1) % n] < cv[(i + 1) % n]:
        d = -1
    if i == 0 and d == 1:
        return cv
    return [cv[(i + d * j) % n] for j in range(n)]


class Cycle(object):
    def __init__(self, vlist):
        self.vlist = tuple(_arrange_cycle(vlist))

    def __hash__(self):
        return hash(self.vlist)

    def __eq__(self, other):
        if type(other) is not Cycle:
            return False
        return self.vlist == other.vlist

    def __repr__(self):
        return "Cycle({})".format(repr(self.vlist))

    def __str__(self):
        return "Cycle({})".format(str(self.vlist))


def bytes_from_cycle(cyc):
    result = bytes_from_int(len(cyc.vlist), 4)
    for v in cyc.vlist:
        result += bytes_from_int(v, 2)
    return result


def cycle_from_bytes(bb, offset):
    n, _ = int_from_bytes(bb, offset, 4)
    cv = [int_from_bytes(bb, offset + 4 + 2 * i, 2)[0] for i in range(n)]
    return Cycle(cv), 2 * n + 4


def bytes_from_cycle_list(cyc_list):
    return b''.join((bytes_from_cycle(cyc) for cyc in cyc_list))


def cycle_list_from_bytes(bb):
    offset = 0
    result = list()
    while offset < len(bb):
        cyc, cyc_len = cycle_from_bytes(bb, offset)
        offset += cyc_len
        result.append(cyc)
    return result


class BXGraphCyc(BXGraph):
    r"""

    BXGraph subclass that also maintains a list of the graph's cycles.

    """
    __slots__ = ["cycles"]

    @classmethod
    def from_bxgraph(cls, bx_graph, cycles):
        return BXGraphCyc(bx_graph.history, bx_graph.size, bx_graph.badj, cycles)

    def __init__(self, history, size, badj, cycles):
        super().__init__(history, size, badj)
        self.cycles = cycles

    def to_list(self):
        return super().to_list() + [self.cycles]

    def to_bytes_list(self):
        return super().to_bytes_list() + [bytes_from_cycle_list(self.cycles).hex()]


def graph_cyc_from_bytes_list(gbc_list):
    r"""

    Restores a BXGraphCyc instance from a list where the history is encoded as an array of bytes

    """
    if len(gbc_list) != 4:
        raise ValueError("BXGraphCyc list representation must be of size 4")

    history, size, badj = graph_elements_from_bytes_list(gbc_list)
    cycles = cycle_list_from_bytes(bytes.fromhex(gbc_list[3]))

    return BXGraphCyc(history, size, badj, cycles)


def _divide_pos(vlist, v1, v2):
    n = len(vlist)
    for i in range(n):
        vp1 = vlist[i]
        vp2 = vlist[(i + 1) % n]
        if (vp1 == v1 and vp2 == v2) or (vp1 == v2 and vp2 == v1):
            return i + 1
    return -1


def apply_subdivide_edge(cycles, v1, v2, w):
    r"""

    Returns the set of cycles that results when the edge between vertices v1
    and v2 is subdivided, adding vertex w. This is the set of cycles, with any
    occurrence of (v1 v2) replaced with (v1 w) and (w v2), and with any
    occurrence of (v2 v1) replaced with (v2 w) and (w v1).

    Complexity: c * n, where c is the number of cycles and n is the number
    of vertices

    """
    result = set()
    for cycle in cycles:
        p = _divide_pos(cycle.vlist, v1, v2)
        if p < 0:
            result.add(cycle)
        elif p == len(cycle.vlist):
            result.add(Cycle(list(cycle.vlist) + [w]))
        else:
            vlist = list(cycle.vlist)
            result.add(Cycle(vlist[:p] + [w] + vlist[p:]))
    return result


def _splices(vlist, v1, v2):
    i1 = vlist.index(v1)
    i2 = vlist.index(v2)
    n = len(vlist)
    vl1 = []
    vl2 = []
    flag = False
    for i in range(n):
        p = (i + i1) % n
        if not(flag):
            vl1.append(vlist[p])
        if p == i2:
            flag = True
        if flag:
            vl2.append(vlist[p])
    vl2.append(v1)
    return vl1, vl2


def _follow_triangle(vlist, i, v):
    newlist = list()
    for j in range(len(vlist)):
        newlist.append(vlist[j])
        if j == i:
            newlist.append(v)
    return newlist


def apply_add_edge(cycles, v1, v2, conn):
    r"""

    Returns the set of cycles that results when a new edge is added between
    vertices v1 and v2. All of the old cycles remain, and for any cycle
    containing v1 and v2, two new cycles are created across the newly chording
    edge.

    Complexity: c * n, where c is the number of cycles and n is the number
    of vertices

    """

    result = set()
    for cycle in cycles:
        result.add(cycle)
        n = len(cycle.vlist)
        vc = sum([1 if v == v1 or v == v2 else 0 for v in cycle.vlist])
        if vc == 2:
            vl1, vl2 = _splices(cycle.vlist, v1, v2)
            result.add(Cycle(vl1))
            result.add(Cycle(vl2))
        elif vc == 1:
            for i in range(n):
                if cycle.vlist[i] == v1 and conn(cycle.vlist[(i - 1) % n], v2):
                    result.add(Cycle(_follow_triangle(cycle.vlist, (i - 1) % n, v2)))
                if cycle.vlist[i] == v1 and conn(cycle.vlist[(i + 1) % n], v2):
                    result.add(Cycle(_follow_triangle(cycle.vlist, i, v2)))
                if cycle.vlist[i] == v2 and conn(cycle.vlist[(i - 1) % n], v1):
                    result.add(Cycle(_follow_triangle(cycle.vlist, (i - 1) % n, v1)))
                if cycle.vlist[i] == v2 and conn(cycle.vlist[(i + 1) % n], v1):
                    result.add(Cycle(_follow_triangle(cycle.vlist, i, v1)))

    return list(result)


def get_pattern(vlist, a, b, c):
    s = ""
    last_known = True
    pa = -1
    pb = -1
    pc = -1
    for v in vlist:
        if v == a:
            pa = len(s)
            s += "a"
            last_known = True
        elif v == b:
            pb = len(s)
            s += "b"
            last_known = True
        elif v == c:
            pc = len(s)
            s += "c"
            last_known = True
        else:
            if last_known:
                s += "*"
            last_known = False
    if pa >= 0:
        s = s[pa:] + s[:pa]
    elif pb >= 0:
        s = s[pb:] + s[:pb]
    elif pc >= 0:
        s = s[pc:] + s[:pc]

    s = s.replace("**", "*")
    return s


def get_index(vlist, a, b, c):
    ai = -1
    bi = -1
    ci = -1
    for i in range(len(vlist)):
        if vlist[i] == a:
            ai = i
        elif vlist[i] == b:
            bi = i
        elif vlist[i] == c:
            ci = i
        if ai >= 0 and bi >= 0 and ci >= 0:
            break
    return ai, bi, ci


class Edge(object):
    def __init__(self, s, t):
        if s < t:
            self.pair = (s, t)
        else:
            self.pair = (t, s)

    def __eq__(self, other):
        if type(other) is not Edge:
            return False

        return self.pair == other.pair

    def __hash__(self):
        return hash(self.pair)


def get_stitch_list(vlist, pair):
    v1, v2 = pair
    n = len(vlist)
    i1 = vlist.index(v1)
    i2 = vlist.index(v2)
    result = list()
    if i2 - i1 == 1:
        for i in range(1, n - 1):
            j = (i2 + i) % n
            result.append(vlist[j])
    else:
        for i in range(1, n - 1):
            j = (i2 - i) % n
            result.append(vlist[j])
    return result


def apply_move_edge(cycles, a, b, c):
    r"""

    Returns the set of cycles that results when an edge (ab) is removed and
    replaced with and edge (ac), where there is an edge (bc).

    Complexity: c^2 * n, where c is the number of cycles in the graph
    and n is the number of vertices.

    """
    result = set()
    new_cycles = set()
    for cycle in cycles:
        n = len(cycle.vlist)
        ai, bi, ci = get_index(cycle.vlist, a, b, c)
        patt = get_pattern(cycle.vlist, a, b, c)
        if patt == "a*b":
            newlist = cycle.vlist[:(bi + 1)] + (c,) + cycle.vlist[(bi + 1):]
            cyc = Cycle(newlist)
            result.add(cyc)
            new_cycles.add(cyc)
        elif patt == "a*c*":
            result.add(cycle)
            newlist1 = list()
            newlist2 = list()
            flag = False
            for i in range(n):
                j = (i + ai) % n
                if not(flag):
                    newlist1.append(cycle.vlist[j])
                if cycle.vlist[j] == c:
                    flag = True
                if flag:
                    newlist2.append(cycle.vlist[j])
            cyc1 = Cycle(newlist1)
            cyc2 = Cycle(newlist2)
            result.add(cyc1)
            result.add(cyc2)
            new_cycles.add(cyc1)
            new_cycles.add(cyc2)
        elif patt == "a*c*b":
            newlist1 = list()
            newlist2 = list()
            flag = False
            for i in range(n):
                j = (i + ai) % n
                if not(flag):
                    newlist1.append(cycle.vlist[j])
                if cycle.vlist[j] == c:
                    flag = True
                if flag:
                    newlist2.append(cycle.vlist[j])
            cyc1 = Cycle(newlist1)
            cyc2 = Cycle(newlist2)
            result.add(cyc1)
            result.add(cyc2)
            new_cycles.add(cyc1)
            new_cycles.add(cyc2)
        elif patt == "a*cb":
            newlist = cycle.vlist[:bi] + cycle.vlist[(bi + 1):]
            cyc = Cycle(newlist)
            result.add(cyc)
            new_cycles.add(cyc)
        elif patt == "ab*":
            newlist = cycle.vlist[:(ai + 1)] + (c,) + cycle.vlist[(ai + 1):]
            cyc = Cycle(newlist)
            result.add(cyc)
            new_cycles.add(cyc)
        elif patt == "ab*c*":
            newlist1 = list()
            newlist2 = list()
            flag = False
            for i in range(n):
                j = (i + bi) % n
                if not(flag):
                    newlist1.append(cycle.vlist[j])
                if cycle.vlist[j] == c:
                    flag = True
                if flag:
                    newlist2.append(cycle.vlist[j])
            cyc1 = Cycle(newlist1)
            cyc2 = Cycle(newlist2)
            result.add(cyc1)
            result.add(cyc2)
            new_cycles.add(cyc1)
            new_cycles.add(cyc2)
        elif patt == "abc*":
            newlist = cycle.vlist[:bi] + cycle.vlist[(bi + 1):]
            cyc = Cycle(newlist)
            result.add(cyc)
            new_cycles.add(cyc)
        elif patt in {"*", "a*", "b*", "c*", "a*b*", "a*b*c*", "a*bc*", "a*c*b*", "a*cb*", "b*c", "b*c*", "bc*"}:
            result.add(cycle)
        elif patt in {"a*bc", "a*c", "ab*c", "ac*", "ac*b", "ac*b*", "acb*"}:
            raise ValueError("Impossible pattern '{}' encountered in cycle {}".format(patt, str(cycle)))
        else:
            raise ValueError("Unexpected pattern '{}' encountered in cycle {}".format(patt, str(cycle)))

        for cyc1 in cycles:
            for cyc2 in cycles:
                if set(cyc1.vlist) & set(cyc2.vlist) != {b}:
                    continue
                n1 = len(cyc1.vlist)
                ai1, bi1, ci1 = get_index(cyc1.vlist, a, b, c)
                patt1 = get_pattern(cyc1.vlist, a, b, c)

                if patt1 not in {"ab*", "a*b"}:
                    continue

                n2 = len(cyc2.vlist)
                ai2, bi2, ci2 = get_index(cyc2.vlist, a, b, c)
                patt2 = get_pattern(cyc2.vlist, a, b, c)

                if patt2 not in {"b*c", "bc*"}:
                    continue

                newlist = list()
                i = 0
                j = ai1 + i
                inc = -1 if cyc1.vlist[(j + 1) % n1] == b else 1
                while j != bi1:
                    newlist.append(cyc1.vlist[j])
                    j = (j + inc) % n1

                i = 0
                j = bi2 + i
                inc = -1 if cyc2.vlist[(j + 1) % n2] == c else 1
                while j != ci2:
                    newlist.append(cyc2.vlist[j])
                    j = (j + inc) % n2
                newlist.append(c)
                cyc = Cycle(newlist)
                result.add(cyc)

    return list(result)


def is_chording_edge(cycle, v1, v2):
    r"""

    Determines whether the edge (v1 v2) is a chording edge of cycle.

    Complexity: n, where n is the number of vertices

    """
    i1 = None
    i2 = None
    n = len(cycle.vlist)
    for i in range(n):
        if cycle.vlist[i] == v1:
            i1 = i
        elif cycle.vlist[i] == v2:
            i2 = i
    if i1 is None or i2 is None:
        return False
    if (i1 - i2) % n in {1, n - 1}:
        return False
    return True


def edge_lies_along_cycle(cycle, vp):
    v1, v2 = vp
    n = len(cycle.vlist)
    return any(((cycle.vlist[i] == v1 and cycle.vlist[(i + 1) % n] == v2) or (cycle.vlist[i] == v2 and cycle.vlist[(i + 1) % n] == v1) for i in range(n)))


def edge_lies_along_path(path, vp):
    v1, v2 = vp
    return any(((path[i] == v1 and path[i + 1] == v2) or (path[i] == v2 and path[i + 1] == v1) for i in range(len(path) - 1)))


def is_chording_path(cycle, path):
    r"""

    Determines whether a path (a list of vertices) is a chording path for a
    cycle - specifically, no edge of the path lies along the cycle, and at
    least one edge meets two vertices in the cycle.

    """
    ce = False
    for i in range(len(path) - 1):
        if edge_lies_along_cycle(cycle, path[i], path[i + 1]):
            return False
        if is_chording_edge(cycle, path[i], path[i + 1]):
            ce = True
    return ce


def gen_igraph(bg):
    r"""

    Creates an igraph.Graph instance from a BXGraph.

    """
    return igraph.Graph.Adjacency(adj_from_bytes(bg.badj, bg.size), mode=igraph.ADJ_UNDIRECTED)


def is_chording_path_es(cycle, path, pvs, pes):
    ncv = sum((1 if v in pvs else 0 for v in cycle.vlist))
    if ncv != 2:
        return False  # not enough common vertices to be a chording path
    n = len(cycle.vlist)
    if any(((cycle.vlist[i], cycle.vlist[(i + 1) % n]) in pes for i in range(n))):
        return False  # edge on path lies along cycle
    cvs = set(cycle.vlist)
    return any((pe[0] in cvs and pe[1] in cvs) for pe in pes)


def any_chording_paths(bgc, g, pairs, ignore_edges):
    r"""

    Determines whether there are chording paths between a list of pairs of
    vertices, given a BXCGraph instance, an igraph.Graph representation of
    the same graph, and a list of pairs of vertex numbers.

    """

    for v1, v2 in pairs:
        paths = g.get_all_simple_paths(v1, [v2])
        for path in paths:
            if any((edge_lies_along_path(path, e) for e in ignore_edges)):
                continue
            pes = set(((path[i], path[i + 1]) for i in range(len(path) - 1))) | set(((path[i + 1], path[i]) for i in range(len(path) - 1)))
            pvs = set(path)
            for cycle in bgc.cycles:
                if any((edge_lies_along_cycle(cycle, e) for e in ignore_edges)):
                    continue
                if is_chording_path_es(cycle, path, pvs, pes):
                    return True

    return False


def v_cycles(g, v):
    cycles = set()
    for v2 in g.neighborhood([v])[0]:
        for path in g.get_all_simple_paths(v2, [v]):
            if len(path) > 2:
                cycles.add(Cycle(path))
    return cycles


def find_cycles(adj):
    g = igraph.Graph.Adjacency(adj, mode=igraph.ADJ_UNDIRECTED)
    cycles = set()
    for i in range(len(adj)):
        cycles.update(v_cycles(g, i))
    return cycles
