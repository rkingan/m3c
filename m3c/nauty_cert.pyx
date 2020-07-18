r"""

This module contains a routine for generating a nauty certificate for a
BXGraph instance.

"""

import pynauty


def gen_cert(bg):
    g = pynauty.Graph(bg.size)

    for i in range(bg.size - 1):
        nbrs = [j for j in range(i + 1, bg.size) if bg.conn(i, j)]
        if len(nbrs) > 0:
            g.connect_vertex(i, nbrs)

    return pynauty.certificate(g)
