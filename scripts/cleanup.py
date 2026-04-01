#!/usr/bin/env python3
"""
cleanup.py -- Delete all Databricks resources created by the labs.

Usage:
    python scripts/cleanup.py

Deletes (in order):
    1. Model Serving endpoints (from Labs 09, 10)
    2. Vector Search index and endpoint (from Lab 02)
    3. Catalog cascade (drops all tables, volume, schema)
"""

import sys
from databricks.sdk import WorkspaceClient

CATALOG = "genai_lab_guide"
VS_ENDPOINT = "genai_lab_guide_vs_endpoint"
VS_INDEX = f"{CATALOG}.default.arxiv_chunks_index"
SERVING_ENDPOINTS = [
    "genai-lab-agent-endpoint",
]


def main():
    print("Cleaning up Databricks resources for GenAI Lab Guide...")
    print()

    confirm = input("This will DELETE all lab resources. Type 'yes' to continue: ")
    if confirm.lower() != "yes":
        print("Aborted.")
        sys.exit(0)

    w = WorkspaceClient()

    # 1. Delete serving endpoints
    print("Deleting Model Serving endpoints...")
    for ep_name in SERVING_ENDPOINTS:
        try:
            w.serving_endpoints.delete(ep_name)
            print(f"  Deleted endpoint: {ep_name}")
        except Exception as e:
            print(f"  Skipped {ep_name}: {e}")

    # 2. Delete Vector Search index
    print(f"Deleting Vector Search index: {VS_INDEX}...")
    try:
        w.vector_search_indexes.delete_index(VS_INDEX)
        print(f"  Deleted index: {VS_INDEX}")
    except Exception as e:
        print(f"  Skipped: {e}")

    # 3. Delete Vector Search endpoint
    print(f"Deleting Vector Search endpoint: {VS_ENDPOINT}...")
    try:
        w.vector_search_endpoints.delete_endpoint(VS_ENDPOINT)
        print(f"  Deleted endpoint: {VS_ENDPOINT}")
    except Exception as e:
        print(f"  Skipped: {e}")

    # 4. Drop catalog (cascade deletes schema, tables, volume)
    print(f"Dropping catalog: {CATALOG} (cascade)...")
    try:
        w.catalogs.delete(CATALOG, force=True)
        print(f"  Dropped catalog: {CATALOG}")
    except Exception as e:
        print(f"  Skipped: {e}")

    print()
    print("============================================")
    print("  Cleanup complete! All lab resources removed.")
    print("============================================")


if __name__ == "__main__":
    main()
