#!/usr/bin/env python3

import sys
import os
import re
import subprocess
from pathlib import Path

try:
    import hjson
except ImportError:
    print("Error: 'hjson' module is required. Install with 'pip install hjson'.")
    sys.exit(1)

# Terminal coloring
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RESET = "\033[0m"

# Global cache for resolved revisions to avoid redundant network calls
REVISION_CACHE = {}

def resolve_to_hash(url, rev):
    """Resolve a git revision (tag, branch, or short hash) to a full commit hash."""
    cache_key = (url, rev)
    if cache_key in REVISION_CACHE:
        return REVISION_CACHE[cache_key]

    # If it's already a 40-character hex string, assume it's a full hash
    if re.match(r'^[0-9a-f]{40}$', rev):
        REVISION_CACHE[cache_key] = rev
        return rev

    try:
        # Try to resolve via git ls-remote
        result = subprocess.run(
            ['git', 'ls-remote', url, rev],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout:
            lines = result.stdout.strip().split('\n')
            # Prefer the peeled tag (hash^{}) if it exists
            peeled = [l for l in lines if l.endswith('^{}')]
            resolved = peeled[0].split('\t')[0] if peeled else lines[0].split('\t')[0]
            REVISION_CACHE[cache_key] = resolved
            return resolved
    except Exception:
        pass

    # Fallback to original rev if resolution fails
    REVISION_CACHE[cache_key] = rev
    return rev

def normalize_url(url):
    """Normalize URL to ensure accurate duplicate matching."""
    url = url.strip().lower()
    # Remove protocol (http, https, ssh)
    url = re.sub(r'^(https?|ssh)://', '', url)
    # Remove user (e.g., git@)
    url = re.sub(r'^[^/]*@', '', url)
    # Replace : with / (common in SSH URLs like git@github.com:user/repo)
    url = url.replace(':', '/')
    if url.endswith('.git'):
        url = url[:-4]
    if url.endswith('/'):
        url = url[:-1]
    return url

def check_dependencies(search_path="."):
    vendor_files = list(Path(search_path).rglob("*.vendor.hjson"))

    # Dictionary to group dependencies by normalized URL
    # Format: { 'url': [ {'path': Path, 'rev': str, 'target': str, 'pulled_in': bool}, ... ] }
    deps_by_url = {}

    for v_file in vendor_files:
        try:
            with open(v_file, 'r') as f:
                data = hjson.load(f)

            # Determine vendor name from filename (e.g., "foo.vendor.hjson" -> "foo")
            vendor_filename_base = v_file.name.rsplit(".", 2)[0]

            # Unify formats into a dictionary of project_data
            if "name" in data:
                # Single-entry format: wrap in a dict with its name as key
                projects = {data["name"]: data}
                is_multi = False
            else:
                # Multi-entry format
                projects = data
                is_multi = True

            for project_name, project_data in projects.items():
                if not isinstance(project_data, dict):
                    continue

                upstream = project_data.get("upstream", {})
                url = upstream.get("url")
                rev = upstream.get("rev", "UNKNOWN")

                if not url:
                    continue

                # Determine target_dir following vendor.py logic
                if "target_dir" in project_data:
                    target_dir_name = project_data["target_dir"]
                elif not is_multi:
                    # Single-entry usually requires target_dir; if missing, it's invalid or at the same level
                    target_dir_name = ""
                else:
                    # Multi-entry default: <vendor_name>/<project_name>
                    target_dir_name = str(Path(vendor_filename_base) / project_name)

                norm_url = normalize_url(url)
                target_path = v_file.parent / target_dir_name

                # Determine if the dependency was actually pulled in
                is_pulled_in = target_path.is_dir() and any(target_path.iterdir())

                if norm_url not in deps_by_url:
                    deps_by_url[norm_url] = []
                    
                deps_by_url[norm_url].append({
                    'path': v_file,
                    'url': url,
                    'rev': rev,
                    'target': target_path,
                    'pulled_in': is_pulled_in
                })
            
        except Exception as e:
            print(f"{YELLOW}Warning: Could not parse {v_file}: {e}{RESET}")

    global_errors = 0

    print(f"Checking {len(deps_by_url)} unique dependencies...\n")
    print(f"{'STATUS':<12} {'REPOSITORY':<60} {'REVISION':<40} {'LOCATION'}")
    print("-" * 180)

    # Evaluate dependencies
    for norm_url in sorted(deps_by_url.keys()):
        entries = deps_by_url[norm_url]
        
        # Resolve revisions for all if they are duplicates to find true mismatches early
        if len(entries) > 1:
            for entry in entries:
                entry['resolved_rev'] = resolve_to_hash(entry['url'], entry['rev'])
            resolved_revisions = {entry['resolved_rev'] for entry in entries}
            rev_mismatch = len(resolved_revisions) > 1
            pulled_in_count = sum(1 for entry in entries if entry['pulled_in'])
            multiple_pulls = pulled_in_count > 1
        else:
            rev_mismatch = False
            multiple_pulls = False

        for entry in entries:
            status = "PULLED" if entry['pulled_in'] else "NOT PULLED"
            status_color = GREEN if entry['pulled_in'] else RESET
            
            if (entry['pulled_in'] and multiple_pulls) or rev_mismatch:
                status_color = RED
                if multiple_pulls and entry['pulled_in']:
                    status = "DUPLICATE"
                elif rev_mismatch:
                    status = "MISMATCH"

            rev_display = entry['rev']
            if rev_mismatch:
                rev_display = f"{RED}{rev_display}{RESET}"

            print(f"{status_color}{status:<12}{RESET} {entry['url']:<60} {rev_display:>40} {entry['path']}")

    # Detailed collision reports
    for norm_url, entries in deps_by_url.items():
        if len(entries) <= 1:
            continue

        # We already resolved hashes in the summary loop for duplicates
        resolved_revisions = {entry['resolved_rev'] for entry in entries}
        rev_mismatch = len(resolved_revisions) > 1
        pulled_in_count = sum(1 for entry in entries if entry['pulled_in'])
        multiple_pulls = pulled_in_count > 1

        if not (rev_mismatch or multiple_pulls):
            continue

        print(f"\n{'-'*80}")
        print(f"Dependency Collisions Detected for: {norm_url}")
        print(f"{'-'*80}")

        for i, entry in enumerate(entries, 1):
            path_str = str(entry['path'])
            rev_str = entry['rev']
            resolved_hash = entry['resolved_rev']
            
            status = []
            if entry['pulled_in']:
                status.append("PULLED IN")
            else:
                status.append("NOT PULLED")
                
            if rev_mismatch:
                rev_str = f"{RED}{rev_str}{RESET}"
                resolved_hash = f"{RED}{resolved_hash}{RESET}"
                
            if entry['pulled_in'] and multiple_pulls:
                status_str = f"{RED}{', '.join(status)} (DUPLICATE){RESET}"
            else:
                status_str = f"{GREEN}{', '.join(status)}{RESET}"

            print(f"  [{i}] {path_str}")
            print(f"      Revision: {rev_str}")
            print(f"      Commit:   {resolved_hash}")
            print(f"      Status:   {status_str}\n")

        # Report specific errors and instructions
        if rev_mismatch or multiple_pulls:
            global_errors += 1
            print(f"{RED}ERRORS FOUND:{RESET}")
            
            if rev_mismatch:
                print(f"  * Revision mismatch: multiple required versions for the same IP.")
            
            if multiple_pulls:
                print(f"  * Duplicate instantiation: IP is pulled into multiple directories.")
                
            print("\nREQUIRED ACTION:")
            print("  1. Choose ONE primary .vendor.hjson file to maintain the dependency (usually at the top-level).")
            print("  2. In all other projects dependent on this IP, add the vendor directory to 'exclude_from_upstream' in their respective .vendor.hjson files.")
            print("  3. Run the 'vendor-update' target again.")

    if global_errors > 0:
        print(f"\n{RED}Failure: Found {global_errors} dependency collision(s) requiring resolution.{RESET}")
        sys.exit(1)
    else:
        print(f"{GREEN}Dependency check passed. No collisions found.{RESET}")
        sys.exit(0)

if __name__ == "__main__":
    check_dependencies()
    sys.exit(0)
