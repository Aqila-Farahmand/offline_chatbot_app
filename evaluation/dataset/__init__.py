import os
from deepeval import evaluate
from deepeval.test_case import Turn, TurnParams, ConversationalTestCase
from deepeval.metrics import ConversationalGEval
from pathlib import Path

# Path to the dataset directory
PATH = Path(__file__).parent
