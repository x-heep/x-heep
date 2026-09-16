#!/usr/bin/env python3
# Copyright 2020 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
import argparse
import sys
from git import Repo


def main():
    repo = Repo(search_parent_directories=True)

    parser = argparse.ArgumentParser(
        description='Check for changes in repository')
    parser.add_argument('--error-msg',
                        default='::error Files differ.',
                        required=False,
                        help='custom exit code string')
    args = parser.parse_args()

    try:
        diff_to_head = repo.head.commit.diff(None)
    except ValueError as e:
        if "SHA could not be resolved" in str(e):
            print("::error ::git-diff.py: Failed to read repository.", file=sys.stderr)
            print("::error ::This can happen if the repository is mounted in a Docker container with a different owner.", file=sys.stderr)
            print("::error ::To fix this, run 'git config --global --add safe.directory {}' inside the container.".format(
                repo.working_dir), file=sys.stderr)
            exit(1)
        else:
            raise e

    if len(diff_to_head) == 0:
        exit(0)

    print("::error ::The following files differ:")
    for diff in diff_to_head:
        print(
            "::error file={}::- {}".format(diff.b_path, diff.b_path)
        )
    print(args.error_msg)
    exit(1)


if __name__ == '__main__':
    main()