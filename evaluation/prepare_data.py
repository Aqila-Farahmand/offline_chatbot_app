import pandas as pd
from pathlib import Path
from dataset import PATH as DATA_PATH
# Paths
chat_history_path = DATA_PATH / 'chat_history_2025-07-15.csv'
reference_path = DATA_PATH / 'reference_data.csv'

# Load data
chat_df = pd.read_csv(chat_history_path)
ref_df = pd.read_csv(reference_path)

# Merge reference answers into chat history based on the question
chat_df = chat_df.merge(ref_df, on='question', how='left')
chat_df.rename(columns={'answer': 'reference_response'}, inplace=True)
# Ensure all required columns are present
required_cols = {'model_name', 'question', 'response',
                 'reference_response', 'response_time_ms'}
if not required_cols.issubset(chat_df.columns):
    raise ValueError(f"Chat history must contain columns: {required_cols}")

# Save updated chat history with reference responses
chat_df.to_csv(chat_history_path, index=False)
print(
    f"Chat history updated with reference responses. Saved to {chat_history_path}.")
