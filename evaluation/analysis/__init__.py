import os
from pathlib import Path
import tiktoken
from transformers import AutoTokenizer


PATH = Path(__file__).parent
TOKENIZER_CACHE = {}
HUGGINGFACE_TOKEN = os.getenv("HUGGINGFACE_HUB_TOKEN") or os.getenv("HF_TOKEN")
ORIGINAL_HUGGINGFACE_NAME = {
    'gemma3-1b': 'google/gemma-3-1b-it',
    'Gemma3-1B': 'google/gemma-3-1b-it',
    'Qwen2.5-0.5B': 'Qwen/Qwen2.5-0.5B-Instruct',
    'hammer2p1_05b': 'MadeAgents/Hammer2.1-0.5b',
    'SmolLM-135M': 'HuggingFaceTB/SmolLM-135M',
}


def get_tokenizer(model_name: str):
    if model_name in TOKENIZER_CACHE:
        return TOKENIZER_CACHE[model_name]
    else:
        repo = ORIGINAL_HUGGINGFACE_NAME[model_name]
        kwargs = {"trust_remote_code": True}
        if HUGGINGFACE_TOKEN:
            try:
                kwargs["token"] = HUGGINGFACE_TOKEN
                tokenizer = AutoTokenizer.from_pretrained(repo, **kwargs)
                TOKENIZER_CACHE[model_name] = tokenizer
                return tokenizer
            except TypeError:
                kwargs.pop("token", None)
                kwargs["use_auth_token"] = HUGGINGFACE_TOKEN
                tokenizer = AutoTokenizer.from_pretrained(repo, **kwargs)
                TOKENIZER_CACHE[model_name] = tokenizer
                return tokenizer
        else:
            tokenizer = AutoTokenizer.from_pretrained(repo, **kwargs)
            TOKENIZER_CACHE[model_name] = tokenizer
            return tokenizer


def count_tokens(text: str, model_name: str) -> int:
    if not isinstance(text, str) or not text.strip():
        return 0
    tokenizer = get_tokenizer(model_name)
    if tokenizer is None:
        raise ValueError(f"Tokenizer for model '{ORIGINAL_HUGGINGFACE_NAME[model_name]}' not found or not supported.")
    if isinstance(tokenizer, tiktoken.Encoding):
        return len(tokenizer.encode(text))
    else:
        return len(tokenizer.encode(text))