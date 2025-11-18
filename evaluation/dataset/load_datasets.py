import pandas as pd
from datasets import load_dataset
from sklearn.model_selection import train_test_split
from evaluation.dataset import PATH as DATASET_PATH

# Path to the dataset directory
DATASET_NAME = "lavita/ChatDoctor-HealthCareMagic-100k"
OUTPUT_CSV = DATASET_PATH / "chatdoctor_healthcaremagic_100k.csv"
TRAIN_CSV = DATASET_PATH / "chatdoctor_healthcaremagic_train.csv"
TEST_CSV = DATASET_PATH / "chatdoctor_healthcaremagic_test.csv"


def load_data(dataset_name, split=None):
    """
    Load dataset from Hugging Face.

    The dataset contains medical Q&A pairs with:
    - instruction: The system instruction
    - input: The patient's question/description
    - output: The doctor's response

    Args:
        dataset_name: Name of the dataset on Hugging Face
        split: Specific split to load (e.g., 'train', 'test'). If None, returns DatasetDict.

    Returns:
        pd.DataFrame or DatasetDict: The loaded dataset
    """
    print(f"Loading dataset: {dataset_name}")
    print("This may take a few minutes on first download...")

    # Load the dataset from Hugging Face
    if split:
        dataset = load_dataset(dataset_name, split=split)
        # Convert to pandas DataFrame
        df = dataset.to_pandas()
    else:
        dataset_dict = load_dataset(dataset_name)
        print(f"Available splits: {list(dataset_dict.keys())}")

        # If only train split exists, use it
        if 'train' in dataset_dict:
            print("Loading 'train' split...")
            df = dataset_dict['train'].to_pandas()
        else:
            # If multiple splits, return the first one
            first_split = list(dataset_dict.keys())[0]
            print(f"Loading '{first_split}' split...")
            df = dataset_dict[first_split].to_pandas()

    print(f"\nDataset shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")
    print("\nFirst few rows:")
    print(df.head())

    return df


def create_train_test_split(df, test_size=0.2, random_state=42):
    """
    Split the dataset into train and test sets.

    Args:
        df: DataFrame to split
        test_size: Proportion of dataset to use for testing (default: 0.2)
        random_state: Random seed for reproducibility

    Returns:
        tuple: (train_df, test_df)
    """
    print(f"\nSplitting dataset: {len(df)} examples")
    print(
        f"Test size: {test_size * 100}% ({int(len(df) * test_size)} examples)")
    print(
        f"Train size: {(1 - test_size) * 100}% ({int(len(df) * (1 - test_size))} examples)")

    train_df, test_df = train_test_split(
        df,
        test_size=test_size,
        random_state=random_state
    )

    # Save splits
    print(f"\nSaving train split to: {TRAIN_CSV}")
    train_df.to_csv(TRAIN_CSV, index=False)

    print(f"Saving test split to: {TEST_CSV}")
    test_df.to_csv(TEST_CSV, index=False)

    return train_df, test_df


def _determine_csv_path(csv_path, use_test_split):
    """
    Determine which CSV file to use for loading the dataset.

    Args:
        csv_path: Path to the CSV file. If None, auto-determines based on availability.
        use_test_split: If True, prefer test split over full dataset.

    Returns:
        Path object or None if no valid CSV found.
    """
    if csv_path is not None:
        return csv_path

    if use_test_split and TEST_CSV.exists():
        print(f"Using test split: {TEST_CSV}")
        return TEST_CSV

    if TRAIN_CSV.exists():
        print(f"Using train split: {TRAIN_CSV}")
        return TRAIN_CSV

    if OUTPUT_CSV.exists():
        print(f"Using full dataset: {OUTPUT_CSV}")
        return OUTPUT_CSV

    print("Dataset CSV not found. Please run load_data() first.")
    return None


def _find_column_mappings(df):
    """
    Find the actual column names in the DataFrame by mapping common variations.

    Args:
        df: DataFrame to search for columns.

    Returns:
        dict: Mapping of target column names to actual column names found.
    """
    column_mapping = {
        'input': ['input', 'Input', 'question', 'Question', 'text', 'Text'],
        'instruction': ['instruction', 'Instruction', 'system', 'System'],
        'output': ['output', 'Output', 'response', 'Response', 'answer', 'Answer']
    }

    actual_columns = {}
    for target_col, possible_names in column_mapping.items():
        for name in possible_names:
            if name in df.columns:
                actual_columns[target_col] = name
                break

    return actual_columns


def create_test_questions_csv(csv_path=None, use_test_split=True, max_questions=None, random_state=42):
    """
    Create a simplified questions.csv file from the dataset for testing.
    This extracts just the input (patient questions) for evaluation.

    Args:
        csv_path: Path to the CSV file. If None, uses test split if available.
        use_test_split: If True, prefer test split over full dataset.
        max_questions: Maximum number of questions to sample. If None, uses all questions.
        random_state: Random seed for reproducibility when sampling.

    Returns:
        pd.DataFrame: DataFrame with test questions
    """
    # If max_questions is specified, always use full dataset for sampling
    if max_questions is not None:
        if OUTPUT_CSV.exists():
            csv_path = OUTPUT_CSV
            print(
                f"Sampling {max_questions} questions from full dataset: {csv_path}")
        else:
            print("Full dataset not found. Please run load_data() first.")
            return None
    else:
        csv_path = _determine_csv_path(csv_path, use_test_split)
        if csv_path is None:
            return None

    if not csv_path.exists():
        print(
            f"Dataset CSV not found at {csv_path}. Please run load_data() first.")
        return None

    df = pd.read_csv(csv_path)

    print(f"\nLoaded dataset from: {csv_path}")
    print(f"Dataset shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")

    # Sample if max_questions is specified
    if max_questions is not None:
        if max_questions > len(df):
            print(
                f"Warning: Requested {max_questions} questions but only {len(df)} available.")
            print(f"Using all {len(df)} questions.")
        else:
            print(
                f"\nRandomly sampling {max_questions} questions from {len(df)} total...")
            df = df.sample(n=min(max_questions, len(df)),
                           random_state=random_state)
            print(f"Sampled {len(df)} questions.")

    actual_columns = _find_column_mappings(df)

    if 'input' not in actual_columns:
        print(
            f"\nError: Could not find 'input' column. Available columns: {df.columns.tolist()}")
        print("Please check the dataset structure.")
        return None

    # Create a simplified version with just questions
    questions_df = pd.DataFrame({
        'question': df[actual_columns['input']].fillna(''),
    })

    # Add instruction if available
    if 'instruction' in actual_columns:
        questions_df['instruction'] = df[actual_columns['instruction']].fillna(
            '')

    # Add reference response if available
    if 'output' in actual_columns:
        questions_df['reference_response'] = df[actual_columns['output']].fillna(
            '')

    # Save as questions file
    questions_output = DATASET_PATH / "chatdoctor_questions.csv"
    questions_df.to_csv(questions_output, index=False)
    print(f"\nTest questions saved to: {questions_output}")
    print(f"Total questions: {len(questions_df)}")
    print(f"Columns: {questions_df.columns.tolist()}")

    return questions_df


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Load ChatDoctor-HealthCareMagic-100k dataset from Hugging Face")
    parser.add_argument(
        "--create-questions",
        action="store_true",
        help="Also create a simplified questions.csv file for testing"
    )
    parser.add_argument(
        "--split",
        action="store_true",
        help="Split the dataset into train/test sets (80/20)"
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Proportion of dataset to use for testing (default: 0.2)"
    )
    parser.add_argument(
        "--no-use-test-split",
        dest="use_test_split",
        action="store_false",
        default=True,
        help="Don't use test split for creating questions (default: use test split)"
    )
    parser.add_argument(
        "--max-questions",
        type=int,
        default=None,
        help="Maximum number of questions to randomly sample from the dataset (default: use all)"
    )
    parser.add_argument(
        "--random-state",
        type=int,
        default=42,
        help="Random seed for reproducibility when sampling (default: 42)"
    )

    args = parser.parse_args()

    # Load the dataset
    df = load_data(DATASET_NAME)

    # Save full dataset
    print(f"\nSaving full dataset to: {OUTPUT_CSV}")
    df.to_csv(OUTPUT_CSV, index=False)
    print(f"Dataset saved successfully to {OUTPUT_CSV}")

    # Optionally split into train/test
    if args.split:
        train_df, test_df = create_train_test_split(
            df, test_size=args.test_size)
        print("\nTrain/test split completed!")
        print(f"Train: {len(train_df)} examples")
        print(f"Test: {len(test_df)} examples")

    # Optionally create a simplified questions CSV
    if args.create_questions:
        create_test_questions_csv(
            use_test_split=args.use_test_split,
            max_questions=args.max_questions,
            random_state=args.random_state
        )
