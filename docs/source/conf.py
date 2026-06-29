# Copyright 2023 EPFL
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Author: Embedded Systems Laboratory (EPFL)

import os
import sys

sys.path.insert(0, os.path.abspath("../../util"))
sys.path.insert(0, os.path.abspath("../../util/xheep_gen"))

project = "X-HEEP"
copyright = "2025, EPFL"
author = "ESL"

release = "1.0"
version = "1.0.0"

extensions = [
    "sphinx.ext.duration",
    "sphinx.ext.doctest",
    "sphinx.ext.autodoc",
    "sphinx.ext.autosummary",
    "sphinx.ext.intersphinx",
    "sphinxcontrib.apidoc",
    "myst_parser",
]

source_suffix = [".rst", ".md"]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3/", None),
    "sphinx": ("https://www.sphinx-doc.org/en/master/", None),
}
intersphinx_disabled_domains = ["std"]

templates_path = ["_templates"]

html_theme = "sphinx_rtd_theme"

html_logo = "images/x-heep-outline.png"

epub_show_urls = "footnote"

apidoc_module_dir = os.path.abspath("../../util/xheep_gen")
apidoc_output_dir = "Configuration/xheep_gen"
apidoc_separate_modules = True
apidoc_toc_file = "index"

# Auto-generate header anchors for MyST
myst_heading_anchors = 4
