import pandas as pd
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import matplotlib.pyplot as plt
import seaborn as sns
from dataset import PATH as DATA_PATH

# Paths
chat_history_path = DATA_PATH / 'chat_history_2025-07-15.csv'
# Ensure the required columns are present
required_cols = {'model_name', 'question', 'response',
                 'reference_response', 'response_time_ms'}
if not required_cols.issubset(pd.read_csv(chat_history_path).columns):
    raise ValueError(f"CSV must contain columns: {required_cols}")

# Load data
chat_df = pd.read_csv(chat_history_path)

# Calculate cosine similarity (TF-IDF) between response and reference_response
vectorizer = TfidfVectorizer()
similarities = []
for idx, row in chat_df.iterrows():
    texts = [str(row['response']), str(row['reference_response'])]
    tfidf = vectorizer.fit_transform(texts)
    sim = cosine_similarity(tfidf[0], tfidf[1])[0][0]
    similarities.append(sim)
chat_df['tfidf_cosine_similarity'] = similarities

# Save updated chat history with similarity scores
chat_df.to_csv(chat_history_path, index=False)

# Plot similarity scores by model
plt.figure(figsize=(10, 6))
sns.boxplot(x='model_name', y='tfidf_cosine_similarity', data=chat_df)
plt.title('TF-IDF Cosine Similarity of Model Responses vs Reference')
plt.ylabel('Cosine Similarity')
plt.xlabel('Model Name')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('similarity_scores_by_model.png')
plt.show()
