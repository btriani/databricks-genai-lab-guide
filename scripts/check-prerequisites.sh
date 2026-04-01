#!/usr/bin/env bash
# check-prerequisites.sh -- Verify all tools required for Databricks GenAI labs
set -euo pipefail

PASS=0
FAIL=0
WARN=0

check_cmd() {
  local name="$1"
  local cmd="$2"
  local version_flag="${3:---version}"

  if command -v "$cmd" &>/dev/null; then
    local ver
    ver=$($cmd $version_flag 2>&1 | head -1)
    printf "  [PASS] %-25s %s\n" "$name" "$ver"
    ((PASS++))
  else
    printf "  [FAIL] %-25s not found\n" "$name"
    ((FAIL++))
  fi
}

check_python_version() {
  if command -v python3 &>/dev/null; then
    local ver
    ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
      printf "  [PASS] %-25s %s (>= 3.10 required)\n" "Python version" "$ver"
      ((PASS++))
    else
      printf "  [FAIL] %-25s %s (3.10+ required)\n" "Python version" "$ver"
      ((FAIL++))
    fi
  fi
}

check_python_pkg() {
  local pkg="$1"
  if python3 -c "import $pkg" &>/dev/null 2>&1; then
    local ver
    ver=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "installed")
    printf "  [PASS] %-25s %s\n" "pip: $pkg" "$ver"
    ((PASS++))
  else
    printf "  [FAIL] %-25s not installed (run: pip install %s)\n" "pip: $pkg" "$pkg"
    ((FAIL++))
  fi
}

check_databricks_auth() {
  if databricks auth describe &>/dev/null 2>&1; then
    local host
    host=$(databricks auth describe 2>&1 | grep -i "host" | head -1 || echo "authenticated")
    printf "  [PASS] %-25s %s\n" "Databricks auth" "$host"
    ((PASS++))
  else
    printf "  [FAIL] %-25s not configured (run: databricks configure)\n" "Databricks auth"
    ((FAIL++))
  fi
}

echo "============================================"
echo "  Databricks GenAI Lab Guide — Prerequisites"
echo "============================================"
echo ""

echo "--- Core Tools ---"
check_cmd "Databricks CLI" "databricks" "version"
check_cmd "Python 3" "python3" "--version"
check_cmd "pip" "pip3" "--version"
check_cmd "Git" "git" "--version"

echo ""
echo "--- Python Version ---"
check_python_version

echo ""
echo "--- Python Packages ---"
check_python_pkg "databricks.sdk"
check_python_pkg "mlflow"
check_python_pkg "langchain"

echo ""
echo "--- Databricks Authentication ---"
check_databricks_auth

echo ""
echo "--- Optional ---"
check_cmd "GitHub CLI (gh)" "gh" "--version"

echo ""
echo "============================================"
TOTAL=$((PASS + FAIL + WARN))
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings (of $TOTAL checks)"

if [ "$FAIL" -eq 0 ]; then
  echo "  Status:  Ready to go! Run: python scripts/setup-catalog.py"
else
  echo "  Status:  Fix the FAIL items above before starting labs."
fi
echo "============================================"

exit "$FAIL"
