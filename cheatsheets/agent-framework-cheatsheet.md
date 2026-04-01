# Agent Framework Cheatsheet

Quick reference for building and deploying agents on Databricks.

---

## MLflow

### Tracing & Logging
```python
import mlflow

# Enable automatic LangChain tracing
mlflow.langchain.autolog(log_traces=True)

# Log a LangChain model (chain or agent)
mlflow.langchain.log_model(
    lc_model=chain,
    artifact_path="rag_chain"
)

# Log a custom ChatAgent
mlflow.pyfunc.log_model(
    artifact_path="agent",
    python_model=ChatAgent        # class, not instance
)
```

### Registry
```python
# Point MLflow at Unity Catalog registry
mlflow.set_registry_uri("databricks-uc")

# Register a logged model
mlflow.register_model(
    model_uri="runs:/<run_id>/agent",
    name="catalog.schema.my_agent"
)
```

### Traces
```python
# Query traces for an experiment
traces = mlflow.search_traces(
    experiment_ids=["<experiment_id>"]
)
```

### Evaluation
```python
results = mlflow.evaluate(
    model="runs:/<run_id>/agent",
    data=eval_df,                          # DataFrame with "inputs" column
    model_type="databricks-agent"
)
```

---

## LangChain

### Databricks LLM
```python
from langchain_community.chat_models import ChatDatabricks

llm = ChatDatabricks(endpoint="databricks-meta-llama-3-1-70b-instruct")
```

### Defining Tools
```python
from langchain.tools import tool

@tool
def search_knowledge_base(query: str) -> str:
    """Search the internal knowledge base for relevant documents."""
    # ... retrieval logic ...
    return results
```

### Building an Agent
```python
from langchain.agents import create_tool_calling_agent, AgentExecutor
from langchain_core.prompts import ChatPromptTemplate

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a helpful assistant. Use tools when needed."),
    ("placeholder", "{chat_history}"),
    ("human", "{input}"),
    ("placeholder", "{agent_scratchpad}"),
])

agent = create_tool_calling_agent(llm, tools, prompt)

executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True
)

response = executor.invoke({"input": "What is the refund policy?"})
```

---

## Unity Catalog (UC) Functions as Tools

### Create a UC Function — SQL
```sql
CREATE OR REPLACE FUNCTION catalog.schema.calculate_discount(
    price    DOUBLE,
    pct      DOUBLE
)
RETURNS DOUBLE
COMMENT 'Returns price after applying discount percentage.'
RETURN price * (1 - pct / 100);
```

### Create a UC Function — Python
```sql
CREATE OR REPLACE FUNCTION catalog.schema.extract_keywords(text STRING)
RETURNS ARRAY<STRING>
LANGUAGE PYTHON
AS $$
import re
return re.findall(r'\b\w{4,}\b', text.lower())
$$;
```

### Wrap UC Functions as LangChain Tools
```python
from unitycatalog.ai.langchain.toolkit import UCFunctionToolkit

toolkit = UCFunctionToolkit(
    function_names=[
        "catalog.schema.calculate_discount",
        "catalog.schema.extract_keywords"
    ]
)
tools = toolkit.tools
```

---

## ChatAgent

### Minimal Implementation
```python
from databricks_langchain import ChatAgent
from mlflow.types.agent import ChatAgentResponse, ChatAgentMessage

class MyAgent(ChatAgent):
    def predict(
        self,
        messages,           # list[ChatAgentMessage]
        context=None,       # optional ChatContext
        custom_inputs=None  # optional dict
    ) -> ChatAgentResponse:
        # Build response using self.llm, tools, etc.
        reply = "Hello from MyAgent!"
        return ChatAgentResponse(
            messages=[
                ChatAgentMessage(role="assistant", content=reply)
            ]
        )
```

### Log and Register
```python
import mlflow

mlflow.set_registry_uri("databricks-uc")

with mlflow.start_run():
    mlflow.pyfunc.log_model(
        artifact_path="agent",
        python_model=MyAgent
    )
    run_id = mlflow.active_run().info.run_id

mlflow.register_model(
    model_uri=f"runs:/{run_id}/agent",
    name="catalog.schema.my_agent"
)
```

---

## Model Serving

### Deploy a Registered Model
```python
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.serving import (
    EndpointCoreConfigInput,
    ServedEntityInput,
)

w = WorkspaceClient()

w.serving_endpoints.create_and_wait(
    name="my-agent-endpoint",
    config=EndpointCoreConfigInput(
        served_entities=[
            ServedEntityInput(
                entity_name="catalog.schema.my_agent",
                entity_version="1",
                workload_size="Small",     # "Small" | "Medium" | "Large"
                scale_to_zero_enabled=True
            )
        ]
    )
)
```

### A/B Testing — Multiple Versions
```python
EndpointCoreConfigInput(
    served_entities=[
        ServedEntityInput(
            entity_name="catalog.schema.my_agent",
            entity_version="1",
            workload_size="Small",
            scale_to_zero_enabled=True,
            traffic_percentage=70
        ),
        ServedEntityInput(
            entity_name="catalog.schema.my_agent",
            entity_version="2",
            workload_size="Small",
            scale_to_zero_enabled=True,
            traffic_percentage=30
        ),
    ]
)
```

### Query an Endpoint
```python
response = w.serving_endpoints.query(
    name="my-agent-endpoint",
    dataframe_records=[{"messages": [{"role": "user", "content": "Hello"}]}]
)
```

---

## Batch Inference

### SQL via `ai_query`
```sql
-- Run inference on every row of a table
SELECT
    doc_id,
    cleaned_text,
    ai_query(
        'my-agent-endpoint',
        CONCAT('Summarize the following:\n\n', cleaned_text)
    ) AS summary
FROM catalog.schema.documents;
```

---

## Guardrails

### Contextual Guardrail — LLM Classifier
```python
@tool
def check_topic_scope(user_input: str) -> str:
    """Reject questions outside the supported topic scope."""
    verdict = llm.invoke(
        f"Is the following question related to company HR policy? "
        f"Reply YES or NO only.\n\nQuestion: {user_input}"
    )
    if "NO" in verdict.content.upper():
        return "I can only answer questions about HR policy."
    return "IN_SCOPE"
```

### Safety Guardrail — Regex PII Detection
```python
import re

PII_PATTERNS = {
    "email":   r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+",
    "phone":   r"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b",
    "ssn":     r"\b\d{3}-\d{2}-\d{4}\b",
}

def contains_pii(text: str) -> bool:
    return any(re.search(p, text) for p in PII_PATTERNS.values())
```

### AI Gateway Configuration (YAML / SDK)
```yaml
# Conceptual config — set via Databricks AI Gateway
route:
  input_filter:
    pii_detection: BLOCK        # block requests containing PII
    safety_filter: BLOCK        # block unsafe/harmful inputs
  output_filter:
    pii_detection: BLOCK        # redact PII from responses
    safety_filter: BLOCK        # block unsafe outputs
```

---

## Evaluation

### MLflow Built-in Evaluation
```python
results = mlflow.evaluate(
    model="runs:/<run_id>/agent",
    data=eval_df,
    model_type="databricks-agent"
)
print(results.metrics)
```

### Custom GenAI Metric
```python
from mlflow.metrics.genai import make_genai_metric, EvaluationExample

faithfulness = make_genai_metric(
    name="faithfulness",
    definition="Does the answer only use information from the provided context?",
    grading_prompt=(
        "Score 1–5: 1 = hallucinated, 5 = fully grounded in context.\n"
        "Context: {context}\nAnswer: {output}"
    ),
    model="endpoints:/databricks-meta-llama-3-1-70b-instruct",
    examples=[
        EvaluationExample(input="...", output="...", score=5, justification="...")
    ]
)
```

### Databricks Agents Evaluate
```python
from databricks import agents

results = agents.evaluate(
    model="catalog.schema.my_agent",
    data=eval_df,
    evaluation_config={
        "metrics": ["groundedness", "relevance", "safety"]
    }
)
```

---

## Monitoring

### Enable Inference Table on Serving Endpoint
```python
from databricks.sdk.service.serving import AutoCaptureConfigInput

w.serving_endpoints.create_and_wait(
    name="my-agent-endpoint",
    config=EndpointCoreConfigInput(
        served_entities=[...],
        auto_capture_config=AutoCaptureConfigInput(
            catalog_name="catalog",
            schema_name="schema",
            table_name_prefix="agent_inference"
        )
    )
)
```

### Create a Lakehouse Monitor
```python
from databricks.sdk.service.catalog import MonitorTimeSeries

w.quality_monitors.create(
    table_name="catalog.schema.agent_inference_payload",
    time_series=MonitorTimeSeries(
        timestamp_col="timestamp",
        granularities=["1 day"]
    ),
    output_schema_name="catalog.schema"
)
```
