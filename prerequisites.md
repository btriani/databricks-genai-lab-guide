# Prerequisites

Everything you need before starting the labs.

## 1. Databricks Workspace

You need a Databricks workspace with **pay-as-you-go** pricing. Community Edition will NOT work — it lacks Unity Catalog, Vector Search, and Model Serving.

Sign up: [https://www.databricks.com/try-databricks](https://www.databricks.com/try-databricks)

> **Important:** Choose the pay-as-you-go plan. You only pay for what you use. Total cost for all labs is ~$15-25.

### Required Features

Your workspace must have:
- **Unity Catalog** enabled (default on new workspaces)
- **Serverless compute** available
- **Foundation Model APIs** access (DBRX, Meta Llama, etc.)

## 2. Databricks CLI

Used by setup and cleanup scripts.

**macOS:**
```bash
brew tap databricks/tap
brew install databricks
```

**Windows / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
```

Full install docs: [https://docs.databricks.com/en/dev-tools/cli/install.html](https://docs.databricks.com/en/dev-tools/cli/install.html)

### Authenticate

```bash
databricks configure
```

Enter your workspace URL (e.g., `https://adb-1234567890.12.azuredatabricks.net`) and a personal access token.

Alternatively, use OAuth:
```bash
databricks auth login --host https://your-workspace-url
```

## 3. Python 3.10+

Required for notebooks and setup scripts.

**macOS:**
```bash
brew install python@3.12
```

**Windows:**
```powershell
winget install Python.Python.3.12
```

**Linux:**
```bash
sudo apt install python3.12 python3.12-venv
```

### Python Packages

Install locally (for running setup scripts):
```bash
pip install databricks-sdk mlflow langchain langchain-community
```

> **Note:** Notebooks install their own dependencies via `%pip` — you don't need to install everything locally.

## 4. Git

For cloning this repo and version control.

```bash
git --version
# Should show 2.40+ (or latest)
```

## 5. Cluster Configuration

When creating a cluster for the labs, use these settings:
- **Runtime:** DBR 15.4 LTS ML (or newer)
- **Node type:** Single node, Standard_DS3_v2 (or equivalent)
- **Autoscaling:** Disabled (single node is sufficient)
- **Auto-termination:** 30 minutes (saves cost)

> **Cost tip:** Use serverless compute when available — it starts faster and you only pay per-second of usage.

## Verification

Run the prerequisites check:
```bash
./scripts/check-prerequisites.sh
```

## Next Step

Run the setup script, then start Lab 01:
```bash
python scripts/setup-catalog.py
```

Start with [Lab 01: Document Parsing & Chunking](labs/01-document-parsing-chunking/workbook.md).
