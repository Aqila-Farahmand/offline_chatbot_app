import fire
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from evaluation.results import PATH as RESULTS_PATH
from evaluation.analysis import PATH as ANALYSIS_PATH


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
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(ANALYSIS_PATH / "response_time_distribution.png")
    plt.savefig(ANALYSIS_PATH / "response_time_distribution.pdf")
    plt.close()



if __name__ == '__main__':
    fire.Fire(generate_time_plot)