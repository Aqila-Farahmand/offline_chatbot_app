from pathlib import Path
import os
import requests
import google.generativeai as genai


PATH = Path(__file__).parent
DEFAULT_GEMINI_MODEL = "gemini-1.5-pro"
MODEL = genai.GenerativeModel(DEFAULT_GEMINI_MODEL)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEVAL_DIMENSIONS = ["soundness", "understandability", "actionability", "concision", "transparency"]

genai.configure(api_key=GEMINI_API_KEY)


def test():
    response = MODEL.generate_content(
        "What is the capital of France?"
    )
    print("Response:", response.text)


def _call_gemini(prompt_text: str) -> list[int]:
    generation_config = {
        "temperature": 0.0,
        "max_output_tokens": 20,
    }
    resp = MODEL.generate_content(
        prompt_text,
    ).text
    if not resp:
        raise ValueError("No response from Gemini API.")
    scores = [int(x.strip()) for x in resp.split(",")]
    if len(scores) != len(GEVAL_DIMENSIONS):
        raise ValueError(f"Expected {len(GEVAL_DIMENSIONS)} scores, got {len(scores)}.")
    return scores

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

    answer = f"'{answer}'"
    instructions = instructions.replace("{{question}}", question).replace("{{answer}}", answer)

    return instructions


def compute_geval_score(answers: list, questions: list) -> list[list[int]]:
    """
    Compute the G-Eval score between answers and questions.

    :param answers: List of generated answers.
    :param questions: List of reference questions.
    :return: G-Eval score as a float.
    """
    if len(answers) != len(questions):
        raise ValueError("Answers and questions must have the same length.")

    if GEMINI_API_KEY is None:
        raise ValueError("GEMINI_API_KEY environment variable is not set.")

    scores = []
    for answer, reference in zip(answers, questions):
        prompt_text = generate_instructions(reference, answer)
        try:
            score = _call_gemini(prompt_text)
            scores.append(score)
        except requests.RequestException as e:
            raise RuntimeError(f"Error calling Gemini API: {e}")
        except ValueError as e:
            raise ValueError(f"Error processing response from Gemini API: {e}")

    return scores


def generate_geval_file(
    answers: list[str],
    questions: list[str],
    output_file: str
) -> None:
    """
    Generate a G-Eval score file.

    :param answers: List of generated answers.
    :param questions: List of reference questions.
    :param output_file: Path to the output file.
    """

    # If the file already exists, skip the generation
    if Path(output_file).exists():
        print(f"{output_file} already exists. Skipping generation.")
        return

    scores = compute_geval_score(answers, questions)

    with open(output_file, "w") as file:
        file.write(",".join(GEVAL_DIMENSIONS) + "\n")
        for score in scores:
            file.write(",".join(map(str, score)) + "\n")

    print(f"G-Eval scores saved to {output_file}")
