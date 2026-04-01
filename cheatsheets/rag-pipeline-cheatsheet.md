# RAG Pipeline Cheatsheet

Quick reference for building RAG pipelines on Databricks.

---

## Document Parsing

### `ai_parse_document()` — SQL Syntax
```sql
SELECT ai_parse_document(content, map('version', '2.0')) AS parsed
FROM   read_files('/Volumes/catalog/schema/vol/', format => 'binaryFile');
```

### `ai_parse_document()` — Python (expr) Syntax
```python
from pyspark.sql.functions import expr

df = spark.read.format("binaryFile").load("/Volumes/catalog/schema/vol/")
df = df.withColumn(
    "parsed",
    expr("ai_parse_document(content, map('version', '2.0'))")
)
```

### Supported Formats
| Format | Notes |
|--------|-------|
| PDF    | Text + layout preserved |
| PNG    | OCR applied |
| JPEG   | OCR applied |
| TIFF   | OCR applied |

### Output Structure
| Field | Description |
|-------|-------------|
| `document.pages` | Array of page objects |
| `document.elements` | Array of content elements (text blocks, tables, figures) |
| `error_status` | `null` on success; error string on failure |
| `metadata` | File-level metadata (page count, format, etc.) |

### Useful Companion Functions
```sql
-- List files in a volume
LIST 'dbfs:/Volumes/catalog/schema/volume/';

-- Read raw binary files
SELECT * FROM read_files('/Volumes/catalog/schema/vol/', format => 'binaryFile');
```

---

## Text Cleaning

### `ai_query()` for Semantic Cleaning
```sql
SELECT ai_query(
    'databricks-meta-llama-3-1-70b-instruct',
    CONCAT(
        'Clean the following text extracted from a PDF. ',
        'Remove headers, footers, and page numbers. ',
        'Return only the cleaned text.\n\n',
        raw_text
    )
) AS cleaned_text
FROM raw_docs;
```

### Python via `ai_query`
```python
from pyspark.sql.functions import expr, concat, lit

df = df.withColumn(
    "cleaned_text",
    expr("""
        ai_query(
            'databricks-meta-llama-3-1-70b-instruct',
            CONCAT('Clean this text:\n\n', raw_text)
        )
    """)
)
```

### Quality vs Cost Trade-off
| Approach | Quality | Cost | Best For |
|----------|---------|------|----------|
| `ai_query()` with LLM | High | High | Production pipelines, complex docs |
| Spark UDF + `concat()` | Low | Low | Prototyping, simple text |

---

## Chunking Strategies

### RecursiveCharacterTextSplitter
Tries to split at progressively smaller boundaries:
**paragraph** → **sentence** → **word**

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,       # target characters per chunk
    chunk_overlap=50,     # characters shared between adjacent chunks
    separators=["\n\n", "\n", " ", ""]  # boundary hierarchy
)

chunks = splitter.split_text(document_text)
```

### Key Parameters
| Parameter | Description | Typical Range |
|-----------|-------------|---------------|
| `chunk_size` | Max characters per chunk | 300 – 1000 |
| `chunk_overlap` | Overlap between chunks | 10 – 20% of chunk_size |

### Chunking Trade-offs
| Dimension | Smaller Chunks | Larger Chunks |
|-----------|---------------|---------------|
| Retrieval precision | Higher | Lower |
| Embeddings generated | More | Fewer |
| Context per result | Less | More |
| Cost (embedding + storage) | Higher | Lower |

**Overlap note:** Overlap improves handling of information that spans chunk boundaries; too much overlap increases redundancy and cost.

---

## Embedding Models

### Model Comparison
| Model | Size | Dimensions | Best For |
|-------|------|-----------|----------|
| `databricks-bge-large-en` | 0.44 GB | 1024 | Higher accuracy, longer context |
| `databricks-bge-small-en` | 0.13 GB | 384 | Speed, lower memory footprint |

### Rule of Thumb
Match the model's **max context length** to your **chunk size**.
If chunks are 500 chars (~125 tokens), either model works; for 1000+ char chunks prefer `bge-large`.

### Using an Embedding Endpoint
```python
from mlflow.deployments import get_deploy_client

client = get_deploy_client("databricks")
response = client.predict(
    endpoint="databricks-bge-large-en",
    inputs={"input": ["Sample text to embed"]}
)
embeddings = response["data"][0]["embedding"]  # list of 1024 floats
```

---

## Vector Search

### Create an Endpoint
```python
from databricks.vector_search.client import VectorSearchClient

vsc = VectorSearchClient()
vsc.create_endpoint(
    name="my_vs_endpoint",
    endpoint_type="STANDARD"   # or "STORAGE_OPTIMIZED"
)
```

### Prerequisites for Delta Sync Index
- Source Delta table must have a **unique primary key** column.
- **Change Data Feed (CDF)** must be enabled on the table:
  ```sql
  ALTER TABLE catalog.schema.docs
  SET TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true');
  ```

### Create a Delta Sync Index
```python
index = vsc.create_delta_sync_index(
    endpoint_name="my_vs_endpoint",
    index_name="catalog.schema.docs_index",
    source_table_name="catalog.schema.docs",
    pipeline_type="TRIGGERED",          # or "CONTINUOUS"
    primary_key="doc_id",
    embedding_source_column="cleaned_text",
    embedding_model_endpoint_name="databricks-bge-large-en"
)
```

### Query Types
| Type | Description |
|------|-------------|
| `ANN` (semantic, default) | Approximate nearest-neighbor on embeddings |
| `KEYWORD` | BM25 full-text keyword search |
| `HYBRID` | Combines semantic + keyword scores |

```python
results = index.similarity_search(
    query_text="What is the refund policy?",
    columns=["doc_id", "cleaned_text"],
    num_results=5,
    query_type="ANN"   # "KEYWORD" | "HYBRID"
)
```

### Reranker
Rerankers **reorder** the top-k retrieved results by relevance — they do **NOT** add new documents to the result set.

```python
from mlflow.deployments import get_deploy_client

client = get_deploy_client("databricks")
reranked = client.predict(
    endpoint="databricks-bge-reranker-v2-m3",
    inputs={
        "query": "refund policy",
        "documents": [r["cleaned_text"] for r in results["result"]["data_array"]]
    }
)
```

---

## Key SQL Functions — Quick Reference

| Function | Syntax | Purpose |
|----------|--------|---------|
| `ai_parse_document` | `ai_parse_document(content, map('version', '2.0'))` | Parse binary doc to structured output |
| `ai_query` | `ai_query('endpoint_name', prompt_string)` | Call LLM endpoint inline in SQL |
| `read_files` | `read_files(path, format => 'binaryFile')` | Load binary files as a DataFrame |
| `LIST` | `LIST 'dbfs:/Volumes/cat/sch/vol/'` | Inspect files in a volume path |
