r"""

Contains methods for generating graph extensions and coextensions.

"""

from .bx_graph import AddEdge, DelEdge, AddVertex, Transformation, apply_transformation
from .cycles import gen_igraph, any_chording_paths, apply_add_edge, apply_subdivide_edge, apply_move_edge, BXGraphCyc

GENERATOR_FTNS = list()
CYCLES_FTNS = list()


def e1(bgc):
    r"""

    Generates a single edge-addition for every non-adjacent pair of vertices.

    Complexity: c * n^2, where n is the number of vertices and c is the number
    of cycles

    """
    n = bgc.size
    for i in range(1, n):
        for j in range(i):
            if not(bgc.conn(i, j)):
                tx = Transformation("e1", [AddEdge(i, j)])
                bg = apply_transformation(bgc, tx)
                cycles = apply_add_edge(bgc.cycles, i, j, lambda a, b: bgc.conn(a, b))
                yield BXGraphCyc.from_bxgraph(bg, cycles)


GENERATOR_FTNS.append(e1)
CYCLES_FTNS.append(e1)


def _prev_e(bg):
    last_xform = bg.history.elements[-1]
    if last_xform.alg.startswith("e"):
        return last_xform.ops[0].i, last_xform.ops[0].j
    return None, None


def e2(bgc):
    r"""

    This algorithm is similar to e1, but checks for an edge previously added
    by e1 and only adds new edges adjacent to it.

    Complexity: c * n^2, where n is the number of vertices and c is the number
    of cycles

    """
    last_i, last_j = _prev_e(bgc)
    if last_i is None:
        raise ValueError("Graph's last transformation must be e?")

    n = bgc.size
    for i in range(n):
        if i != last_i and not(bgc.conn(last_i, i)):
            tx = Transformation("e2", [AddEdge(last_i, i)])
            bg = apply_transformation(bgc, tx)
            cycles = apply_add_edge(bgc.cycles, last_i, i, lambda a, b: bgc.conn(a, b))
            yield BXGraphCyc.from_bxgraph(bg, cycles)
        if i != last_j and not(bgc.conn(last_j, i)):
            tx = Transformation("e2", [AddEdge(last_j, i)])
            bg = apply_transformation(bgc, tx)
            cycles = apply_add_edge(bgc.cycles, last_j, i, lambda a, b: bgc.conn(a, b))
            yield BXGraphCyc.from_bxgraph(bg, cycles)


GENERATOR_FTNS.append(e2)
CYCLES_FTNS.append(e2)


def _get_typeb_edge(bg):
    if len(bg.history.elements) > 0 and bg.history.elements[-1].alg.startswith("e"):
        return bg.history.elements[-1].ops[0].i, bg.history.elements[-1].ops[0].j
    return None


def c1(bgc):
    r"""

    Generates coextension graphs from graphs for which an edge has just been
    added, say between vertices a and b. For each vertex c adjacent to b, for
    which there are no chording paths between a and b or between b and c
    (ignoring the edge (ab)), the algorithm generates a new graph by
    subdividing the edge (ab), and then replacing the edge (cb) with an edge
    (cx), where x is the new vertex added by the subdivision. The same process
    is then done for any neighbor of a.

    Complexity: n^3 * c, where n is the number of vertices, e is
    the number of edges, and c is the number of cycles

    """
    e = _get_typeb_edge(bgc)
    if e is None:
        raise ValueError("Algorithm c4 requires an edge added by an e algorithm")
    g = gen_igraph(bgc)
    a, b = e
    n = bgc.size

    for c in range(n):
        if c != a and c != b and bgc.conn(b, c) and not(any_chording_paths(bgc, g, [(a, c), (a, b)], [(a, b), (b, c)])):
            # build the graph
            tx = Transformation("c1", [AddVertex(), DelEdge(a, b), AddEdge(a, n), AddEdge(b, n), DelEdge(b, c), AddEdge(c, n)])
            bg = apply_transformation(bgc, tx)

            # compute the cycles
            cycles = apply_subdivide_edge(bgc.cycles, a, b, n)
            cycles = apply_move_edge(cycles, c, b, n)
            yield BXGraphCyc.from_bxgraph(bg, cycles)

    b, a = e
    for c in range(n):
        if c != a and c != b and bgc.conn(b, c) and not(any_chording_paths(bgc, g, [(a, c), (a, b)], [(a, b), (b, c)])):
            # build the graph
            tx = Transformation("c1", [AddVertex(), DelEdge(a, b), AddEdge(a, n), AddEdge(b, n), DelEdge(b, c), AddEdge(c, n)])
            bg = apply_transformation(bgc, tx)

            # compute the cycles
            cycles = apply_subdivide_edge(bgc.cycles, a, b, n)
            cycles = apply_move_edge(cycles, c, b, n)
            yield BXGraphCyc.from_bxgraph(bg, cycles)


GENERATOR_FTNS.append(c1)
CYCLES_FTNS.append(c1)


def _find_c1_vertices(bgc):
    last_tx = bgc.history.elements[-1]
    if last_tx.alg != "c1":
        return None

    a, b, c, x = last_tx.ops[1].i, last_tx.ops[1].j, last_tx.ops[4].j, last_tx.ops[2].j
    return a, b, c, x


def c2(bgc):
    r"""

    Generates coextension graphs from graphs produced by algorithm c1. Where
    a, b, c and x are as defined in c1, this algorithm looks for all vertices
    d which are neighbors of a and for which there are no chording paths
    between b and d or c and d (disregarding edges (ax), (bx) and (cx)). For
    any such vertex, the algorithm subdivides the edge (ad) adding a new
    vertex y. It then replaces the edge (xa) with an edge (xy).

    Complexity: n^3 * c, where n is the number of vertices and c is the number
    of cycles

    """
    c1_vertices = _find_c1_vertices(bgc)
    if c1_vertices is not None:
        g = gen_igraph(bgc)
        a, b, c, x = c1_vertices
        n = bgc.size
        for d in range(n):
            if d not in {a, b, c, x} and bgc.conn(a, d) and not(any_chording_paths(bgc, g, [(a, b), (a, c), (b, d), (c, d)], [(b, x), (c, x), (a, x), (a, d)])):
                # build the graph
                tx = Transformation("c2", [AddVertex(), DelEdge(a, d), AddEdge(a, n), AddEdge(d, n), DelEdge(x, a), AddEdge(x, n)])
                bg = apply_transformation(bgc, tx)

                # compute the cycles
                cycles = apply_subdivide_edge(bgc.cycles, a, d, n)
                cycles = apply_move_edge(cycles, x, a, n)
                yield BXGraphCyc.from_bxgraph(bg, cycles)
                # look for other possible c4-type splits
                for f in range(n):
                    if f not in {a, b, c, d, x} and bgc.conn(a, f) and not(any_chording_paths(bgc, g, [(f, a), (f, d)], [(f, a), (a, d), (a, x), (x, b), (x, c)])):
                        tx = Transformation("c2", [AddVertex(), DelEdge(a, f), DelEdge(a, d), AddEdge(f, n), AddEdge(a, n), AddEdge(d, n)])
                        bg = apply_transformation(bgc, tx)

                        cycles = apply_subdivide_edge(bgc.cycles, a, d, n)
                        cycles = apply_move_edge(cycles, f, a, n)
                        yield BXGraphCyc.from_bxgraph(bg, cycles)


GENERATOR_FTNS.append(c2)
CYCLES_FTNS.append(c2)


def _find_c3_vertices(bgc):
    last_tx_1 = bgc.history.elements[-1]
    last_tx_2 = bgc.history.elements[-2]

    if not(last_tx_1.alg.startswith("e") and last_tx_2.alg.startswith("e")):
        return None

    v1, v2 = last_tx_1.ops[0].i, last_tx_1.ops[0].j
    v3, v4 = last_tx_2.ops[0].i, last_tx_2.ops[0].j

    if v1 == v4:
        return v2, v1, v3
    elif v1 == v3:
        return v2, v1, v4
    elif v2 == v3:
        return v1, v2, v4
    elif v2 == v4:
        return v1, v2, v3

    return None


def c3(bgc):
    r"""

    If the last two transformations performed on the graph are extensions, and
    they added adjacent edges with vertices a, b and c (where b is common
    between the two edges), and there are no chording paths between a and b, b
    and c or a and c (disregarding (ab) and (bc)), then form a new graph by
    subdividing the edge (ab) adding a new vertex x, and then replacing the
    edge (bc) with an edge (xc).

    Complexity: n^2 * c, where n is the number of vertices and c is the number
    of cycles

    """
    c3v = _find_c3_vertices(bgc)
    if c3v is not None:
        a, b, c = c3v
        n = bgc.size
        g = gen_igraph(bgc)
        if not(any_chording_paths(bgc, g, [(a, b), (b, c), (a, c)], [(a, b), (b, c)])):
            # build the graph
            tx = Transformation("c3", [AddVertex(), DelEdge(a, b), AddEdge(a, n), AddEdge(b, n), DelEdge(c, b), AddEdge(c, n)])
            bg = apply_transformation(bgc, tx)

            # compute the cycles
            cycles = apply_subdivide_edge(bgc.cycles, a, b, n)
            cycles = apply_move_edge(cycles, c, b, n)
            yield BXGraphCyc.from_bxgraph(bg, cycles)


GENERATOR_FTNS.append(c3)
CYCLES_FTNS.append(c3)
