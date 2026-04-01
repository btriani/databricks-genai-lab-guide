# arXiv Papers — Sample Data

These papers are used as sample data across all labs. They are **not bundled** in this repository — the setup script downloads them from arXiv and uploads them to your Databricks volume.

## Papers

| Paper | Authors | Year | arXiv ID | License |
|-------|---------|------|----------|---------|
| Attention Is All You Need | Vaswani et al. | 2017 | [1706.03762](https://arxiv.org/abs/1706.03762) | arXiv nonexclusive-distrib |
| BERT: Pre-training of Deep Bidirectional Transformers | Devlin et al. | 2019 | [1810.04805](https://arxiv.org/abs/1810.04805) | arXiv nonexclusive-distrib |
| Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks | Lewis et al. | 2020 | [2005.11401](https://arxiv.org/abs/2005.11401) | arXiv nonexclusive-distrib |
| LoRA: Low-Rank Adaptation of Large Language Models | Hu et al. | 2021 | [2106.09685](https://arxiv.org/abs/2106.09685) | arXiv nonexclusive-distrib |
| Chain-of-Thought Prompting Elicits Reasoning in LLMs | Wei et al. | 2022 | [2201.11903](https://arxiv.org/abs/2201.11903) | CC BY 4.0 |
| LLaMA: Open and Efficient Foundation Language Models | Touvron et al. | 2023 | [2302.13971](https://arxiv.org/abs/2302.13971) | CC BY 4.0 |
| Constitutional AI: Harmlessness from AI Feedback | Bai et al. | 2022 | [2212.08073](https://arxiv.org/abs/2212.08073) | CC BY 4.0 |
| Toolformer: Language Models Can Teach Themselves to Use Tools | Schick et al. | 2023 | [2302.04761](https://arxiv.org/abs/2302.04761) | arXiv nonexclusive-distrib |

## Why Not Bundled?

Most of these papers use the arXiv nonexclusive distribution license, which does not permit redistribution in third-party repositories. The setup script (`scripts/setup-catalog.py`) downloads them directly from arXiv for your personal use and uploads them to your Databricks workspace.

## Selection Criteria

Papers were chosen for:
1. **Relevance** to Databricks GenAI certification topics (RAG, agents, evaluation, fine-tuning)
2. **Rich content** — text, tables, figures, equations (exercises document parsing capabilities)
3. **Recognition** — well-known papers that readers will find familiar
