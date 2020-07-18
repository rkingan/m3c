r"""

Utility functions for converting objects to/from binary representations.

"""
import sys

BITS = [1, 2, 4, 8, 16, 32, 64, 128]
FLAGS = bytes(BITS)


def bytes_from_int(i, sz=2):
    return i.to_bytes(sz, sys.byteorder)


def int_from_bytes(b, ix, sz=2):
    result = int.from_bytes(b[ix:(ix + sz)], sys.byteorder)
    return result, ix + sz
