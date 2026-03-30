# Yaml

This directory contains Yaml files defining features of the core.


## CSR

The CSR definition file describes the CSRs supported by the core, with fields,
types, legal values, etc.
_(The user manual has authoritative precedence over this file.)_

It is a "superset" for all supported parameters, and one can generate subset
definitions for specific parameters using the script in core-v-verif,
[here](https://github.com/openhwgroup/core-v-verif/blob/cv32e40x/dev/bin/gen_csr_access_test.py).
Example usage shown
[here](https://github.com/openhwgroup/core-v-verif/blob/cv32e40x/dev/cv32e40x/tests/programs/custom/cv32e40x_csr_access_test/README.md)
