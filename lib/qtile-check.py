#!/usr/bin/env python3
# loading it is stronger than parsing it
import logging, sys

logging.disable(logging.CRITICAL)
try:
    from libqtile.confreader import Config
except ImportError:
    import ast
    ast.parse(open(sys.argv[1]).read())
    sys.exit(0)

Config(sys.argv[1]).load()
sys.exit(0)
