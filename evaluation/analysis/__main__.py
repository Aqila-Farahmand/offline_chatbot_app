import fire
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

from evaluation.analysis.geval import generate_geval_file
from evaluation.results import PATH as RESULTS_PATH
from evaluation.analysis import PATH as ANALYSIS_PATH, count_tokens


def generate_time_plot():
    # For all csv file in RESULTS_PATH, collect the response time grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_type -> group by this
    # - question -> ignore
    # - answer -> ignore
    # - response_ms -> collect this
    # Generate boxplot for each model name and prompt type in one single figure

    results = []
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        if "response_ms" not in df.columns:
            continue
        df["response_ms"] = pd.to_numeric(df["response_ms"], errors="coerce")
        results.append(df[["model_name", "prompt_type", "response_ms"]])

    if not results:
        print("No results found.")
        return

    combined_df = pd.concat(results, ignore_index=True)

    combined_df["combination"] = combined_df["model_name"] + " - " + combined_df["prompt_type"]

    palette = sns.color_palette("viridis", len(combined_df["combination"].unique()))

    plt.figure(figsize=(14, 8))
    ax = sns.boxplot(
        data=combined_df,
        x="combination",
        y="response_ms",
        hue="combination",
        palette=palette,
        legend=False
    )
    plt.yscale('log')
    ax.set_title("Response Time Distribution by Model and Prompt Type", fontsize=16)
    # ax.set_xlabel("Model Name - Prompt Type")
    ax.set_ylabel("Response Time (ms)", )
    ax.set_xlabel("")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(ANALYSIS_PATH / "response_time_distribution.png")
    plt.savefig(ANALYSIS_PATH / "response_time_distribution.pdf")
    plt.close()


def generate_token_length_answer_plot():
    # For all csv file in RESULTS_PATH, collect the token length of the answer grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_type -> group by this
    # - question -> ignore
    # - answer -> collect this
    # - response_ms -> ignore
    # Generate boxplot for each model name and prompt type in one single figure

    results = []
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        if "answer" not in df.columns:
            continue
        df["token_length"] = df.apply(lambda row: count_tokens(row["answer"], row["model_name"]),axis=1)
        results.append(df[["model_name", "prompt_type", "token_length"]])

    if not results:
        print("No results found.")
        return

    combined_df = pd.concat(results, ignore_index=True)

    combined_df["combination"] = combined_df["model_name"] + " - " + combined_df["prompt_type"]

    palette = sns.color_palette("viridis", len(combined_df["combination"].unique()))

    plt.figure(figsize=(14, 8))
    ax = sns.violinplot(
        data=combined_df,
        x="combination",
        y="token_length",
        hue="combination",
        palette=palette,
        legend=False,
        cut=0
    )
    ax.set_title("Token Length Distribution by Model and Prompt Type", fontsize=16)
    ax.set_ylabel("Token Length")
    ax.set_xlabel("")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(ANALYSIS_PATH / "token_length_distribution.png")
    plt.savefig(ANALYSIS_PATH / "token_length_distribution.pdf")
    plt.close()


def generate_geval_score_plot():
    # For all csv file in RESULTS_PATH, collect the G-Eval score grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_type -> group by this
    # - question -> collect this
    # - answer -> collect this
    # - response_ms -> ignore
    # Generate boxplot for each model name and prompt type in one single figure

    results = {}
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        # Generate G-Eval scores for each group of model_name and prompt_type
        # Use the generate_geval_file function to generate the G-Eval scores files first
        if "answer" not in df.columns or "question" not in df.columns:
            continue
        unique_combinations = df.groupby(["model_name", "prompt_type"]).size().reset_index().rename(columns={0: "count"})
        if unique_combinations.empty:
            continue
        for _, row in unique_combinations.iterrows():
            model_name = row["model_name"]
            prompt_type = row["prompt_type"]
            key = f"{model_name} - {prompt_type}"
            if key not in results:
                results[key] = []
            # Generate G-Eval scores for the current combination
            generate_geval_file(df, model_name, prompt_type)
            score_file = RESULTS_PATH / f"{model_name}_{prompt_type}_geval_scores.csv"
            if score_file.exists():
                score_df = pd.read_csv(score_file)
                if "geval_score" in score_df.columns:
                    results[key].extend(score_df["geval_score"].tolist())
    if not results:
        print("No G-Eval scores found.")
        return








if __name__ == '__main__':
    fire.Fire(generate_time_plot)
    fire.Fire(generate_token_length_answer_plot)