from pathlib import Path
import os
import requests
import time
from typing import Dict, Any


PATH = Path(__file__).parent
GEMINI_API_URL = "https://api.openai.com/v1/responses"
DEFAULT_GEMINI_MODEL = "gemini-1.5-pro"
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")


def _call_gemini(prompt_text: str, api_key: str, model: str = DEFAULT_GEMINI_MODEL, timeout: int = 30) -> list[int]:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": model,
        "input": prompt_text,
        "temperature": 0.0,
        "max_output_tokens": 20
    }
    resp = requests.post(GEMINI_API_URL, headers=headers, json=payload, timeout=timeout)
    resp.raise_for_status()
    # Assume the response is a text of 5 integers separated by commas
    response_data = resp.json()
    if "choices" not in response_data or not response_data["choices"]:
        raise ValueError("Invalid response from Gemini API.")
    answer_text = response_data["choices"][0]["text"]
    try:
        return [int(x.strip()) for x in answer_text.split(",")]
    except ValueError:
        raise ValueError("Response from Gemini API is not in the expected format of 5 integers.")


def generate_instructions(question: str, answer: str) -> str:
    """
    Generate instructions for the G-Eval score calculation.

    :return: Instructions as a string.
    """
    instruction_file = PATH / "instructions.txt"

    if not instruction_file.exists():
        raise FileNotFoundError(f"Instructions file not found at {instruction_file}")

    with open(instruction_file, "r") as file:
        instructions = file.read()

    instructions = instructions.replace("{{question}}", question).replace("{{answer}}", answer)

    return instructions


def compute_geval_score(answers: list, references: list) -> list[list[int]]:
    """
    Compute the G-Eval score between answers and references.

    :param answers: List of generated answers.
    :param references: List of reference answers.
    :return: G-Eval score as a float.
    """
    if len(answers) != len(references):
        raise ValueError("Answers and references must have the same length.")

    if GEMINI_API_KEY is None:
        raise ValueError("GEMINI_API_KEY environment variable is not set.")

    scores = []
    for answer, reference in zip(answers, references):
        prompt_text = generate_instructions(reference, answer)
        try:
            score = _call_gemini(prompt_text, GEMINI_API_KEY)
            scores.append(score)
        except requests.RequestException as e:
            raise RuntimeError(f"Error calling Gemini API: {e}")
        except ValueError as e:
            raise ValueError(f"Error processing response from Gemini API: {e}")

    return scores


def generate_geval_file(
    answers: list[str],
    references: list[str],
    output_file: str
) -> None:
    """
    Generate a G-Eval score file.

    :param answers: List of generated answers.
    :param references: List of reference answers.
    :param output_file: Path to the output file.
    """

    # If the file already exists, skip the generation
    if Path(output_file).exists():
        print(f"{output_file} already exists. Skipping generation.")
        return

    scores = compute_geval_score(answers, references)

    with open(output_file, "w") as file:
        for score in scores:
            file.write(",".join(map(str, score)) + "\n")

    print(f"G-Eval scores saved to {output_file}")
