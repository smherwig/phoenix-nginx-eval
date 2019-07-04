#!/usr/bin/env python

"""
defines NGX_HAVE_GCC_ATOMIC and NGX_HAVE_POSIX_SEM to 0
in ngx_auto_config.h.
"""

import os
import sys
import tempfile


_USAGE = """
./patch-ngx_auto_config.py <path-to-ngx_auto_config.h>
""".strip()

_defs_to_zero = (
    '#define NGX_HAVE_GCC_ATOMIC',
    '#define NGX_HAVE_POSIX_SEM'
    )

def _usage(errcode):
    sys.stderr.write(_USAGE + '\n')
    sys.exit(errcode)

def main(argv):
    if len(argv) != 2:
        _usage(1)
    path = argv[1]

    fd, tmppath = tempfile.mkstemp(prefix='graphene-patch-')
    out = os.fdopen(fd, 'w')

    with open(path) as f:
        for line in f:
            line = line.rstrip()
            for entry in _defs_to_zero:
                if line.startswith(entry):
                    out.write('%s 0\n' % entry)
                    break
            else:
                out.write(line + '\n')
    out.close()
    os.rename(tmppath, path)

if __name__ == '__main__':
    main(sys.argv)
