import re
import fire
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from evaluation.analysis.geval import generate_geval_file, GEVAL_DIMENSIONS, PATH as GEVAL_PATH
from evaluation.results import PATH as RESULTS_PATH
from evaluation.analysis import PATH as ANALYSIS_PATH, count_tokens


def generate_time_plot():
    # For all csv file in RESULTS_PATH, collect the response time grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_label -> group by this
    # - question -> ignore
    # - response -> ignore
    # - response_time_ms -> collect this
    # Generate boxplot for each model name and prompt type in one single figure

    results = []
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        if "response_time_ms" not in df.columns:
            continue
        df["response_time_ms"] = pd.to_numeric(df["response_time_ms"], errors="coerce")
        results.append(df[["model_name", "prompt_label", "response_time_ms"]])

    if not results:
        print("No results found.")
        return

    combined_df = pd.concat(results, ignore_index=True)

    pretty_prompt_label = combined_df["prompt_label"].str.replace(r'_(\d+)_words', r' (\1 words)', regex=True)
    pretty_prompt_label = pretty_prompt_label.str.replace('_', ' ')

    combined_df["combination"] = combined_df["model_name"] + " - " + pretty_prompt_label
    # Assign a rank to sort the data alphabetically by combination but if there is a number in the prompt label must be in numeric order:
    # Gemma3-1B - baseline, Gemma3-1B - baseline (50 words), Gemma3-1B - baseline (100 words), Gemma3-1B - baseline (500 words), Gemma3-1B - medical safety
    # Qwen...
    # SmolLM...
    # hummer...
    combined_df["rank"] = combined_df["prompt_label"].str.extract(r'(\d+)').fillna(0).astype(int)
    combined_df["rank"] = combined_df["rank"].map({0: 0, 50: 1, 100: 2, 500: 3})
    combined_df = combined_df.sort_values(by=["rank", "model_name",])

    for filter_label in ["baseline", "safety"]:
        filtered_df = combined_df[combined_df["prompt_label"].str.contains(filter_label, case=False)]

        if filtered_df.empty:
            print(f"No data found for {filter_label}.")
            continue

        palette = sns.color_palette("viridis", len(filtered_df["combination"].unique()))

        plt.figure(figsize=(14, 8))
        ax = sns.boxplot(
            data=filtered_df,
            x="combination",
            y="response_time_ms",
            hue="combination",
            palette=palette,
            legend=False
        )
        plt.yscale('log')
        ax.set_ylabel("Response Time (ms)", fontsize=20)
        ax.set_xlabel("")
        plt.xticks(rotation=45, ha="right")
        plt.tight_layout()
        plt.savefig(ANALYSIS_PATH / f"response_time_distribution_{filter_label}.png")
        plt.savefig(ANALYSIS_PATH / f"response_time_distribution_{filter_label}.pdf")
        plt.close()


def generate_token_length_response_plot():
    # For all csv file in RESULTS_PATH, collect the token length of the response grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_label -> group by this
    # - question -> ignore
    # - response -> collect this
    # - response_time_ms -> ignore
    # Generate boxplot for each model name and prompt type in one single figure

    results = []
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        if "response" not in df.columns:
            continue
        df["token_length"] = df.apply(lambda row: count_tokens(row["response"], row["model_name"]),axis=1)
        results.append(df[["model_name", "prompt_label", "token_length"]])

    if not results:
        print("No results found.")
        return

    combined_df = pd.concat(results, ignore_index=True)

    pretty_prompt_label = combined_df["prompt_label"].str.replace(r'_(\d+)_words', r' (\1 words)', regex=True)
    pretty_prompt_label = pretty_prompt_label.str.replace('_', ' ')
    combined_df["combination"] = combined_df["model_name"] + " - " + pretty_prompt_label
    combined_df["rank"] = combined_df["prompt_label"].str.extract(r'(\d+)').fillna(0).astype(int)
    combined_df["rank"] = combined_df["rank"].map({0: 0, 50: 1, 100: 2, 500: 3})
    combined_df = combined_df.sort_values(by=["rank", "model_name",])

    for filter_label in ["baseline", "safety"]:
        filtered_df = combined_df[combined_df["prompt_label"].str.contains(filter_label, case=False)]

        if filtered_df.empty:
            print(f"No data found for {filter_label}.")
            continue

        palette = sns.color_palette("viridis", len(filtered_df["combination"].unique()))

        plt.figure(figsize=(14, 8))
        ax = sns.violinplot(
            data=filtered_df,
            x="combination",
            y="token_length",
            hue="combination",
            palette=palette,
            legend=False,
            cut=0
        )
        ax.set_ylabel("Token Length", fontsize=20)
        ax.set_xlabel("")
        plt.xticks(rotation=45, ha="right")
        plt.tight_layout()
        plt.savefig(ANALYSIS_PATH / f"token_length_distribution_{filter_label}.png")
        plt.savefig(ANALYSIS_PATH / f"token_length_distribution_{filter_label}.pdf")
        plt.close()



def generate_geval_score_plot(dimension: str):
    # For all csv file in RESULTS_PATH, collect the G-Eval score grouped by model name and prompt type
    # Columns are:
    # - time_stamp -> ignore (optional)
    # - model_name -> group by this
    # - prompt_label -> group by this
    # - question -> collect this
    # - response -> collect this
    # - response_time_ms -> ignore
    # Generate boxplot for each model name and prompt type in one single figure

    results = {}
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        # Generate G-Eval scores for each group of model_name and prompt_label
        # Use the generate_geval_file function to generate the G-Eval scores files first
        if "response" not in df.columns or "question" not in df.columns:
            continue
        unique_combinations = df.groupby(["model_name", "prompt_label"]).size().reset_index().rename(columns={0: "count"})
        if unique_combinations.empty:
            continue
        for _, row in unique_combinations.iterrows():
            model_name = row["model_name"]
            prompt_label = row["prompt_label"]
            key = f"{model_name} - {prompt_label}"
            if key not in results:
                results[key] = []
            # Generate G-Eval scores for the current combination
            score_file = GEVAL_PATH / f"{model_name}_{prompt_label}_geval_scores.csv"
            filtered_df = df[(df["model_name"] == model_name) & (df["prompt_label"] == prompt_label)]
            generate_geval_file(filtered_df["response"].values, filtered_df["question"].values, score_file)
            if score_file.exists():
                score_df = pd.read_csv(score_file)
                if dimension in score_df.columns:
                    results[key].extend(score_df[dimension].tolist())
    if not results:
        print(f"No G-Eval scores found for {dimension} dimension.")
        return

    combined_df = pd.DataFrame([
        {"combination": key, "geval_score": score}
        for key, scores in results.items()
        for score in scores
    ])
    combined_df["model_name"], combined_df["prompt_label"] = zip(*combined_df["combination"].str.split(" - "))
    palette = sns.color_palette("viridis", len(combined_df["combination"].unique()))
    plt.figure(figsize=(14, 8))
    ax = sns.violinplot(
        data=combined_df,
        x="combination",
        y="geval_score",
        hue="combination",
        palette=palette,
        legend=False,
        cut=0
    )
    ax.set_title(f"G-Eval Score Distribution by Model and Prompt Type ({dimension})", fontsize=16)
    ax.set_ylabel(f"G-Eval Score ({dimension})")
    ax.set_xlabel("")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(ANALYSIS_PATH / f"geval_score_distribution_{dimension}.png")
    plt.savefig(ANALYSIS_PATH / f"geval_score_distribution_{dimension}.pdf")


def latex_escape(text: str) -> str:
    return text.replace("_", "\\_")


def generate_geval_latex_table():
    # Generate a Latex table with the following columns:
    # - Model Name
    # - Prompt Type
    # - Mean and Std G-Eval Score for each dimension in GEVAL_DIMENSIONS (5 in total)
    # Group by Model Name and Prompt Type (Model Name is multirow)
    # Sort by Model Name alphabetically and Prompt Type alphabetically
    results = {}
    for csv_file in RESULTS_PATH.glob("*.csv"):
        df = pd.read_csv(csv_file)
        if "response" not in df.columns or "question" not in df.columns:
            continue

        unique_combinations = (
            df.groupby(["model_name", "prompt_label"])
            .size()
            .reset_index()
            .rename(columns={0: "count"})
        )
        if unique_combinations.empty:
            continue

        for _, row in unique_combinations.iterrows():
            model_name = row["model_name"]
            prompt_label = row["prompt_label"]
            key = (model_name, prompt_label)

            if key not in results:
                results[key] = {dim: [] for dim in GEVAL_DIMENSIONS}

            score_file = GEVAL_PATH / f"{model_name}_{prompt_label}_geval_scores.csv"
            filtered_df = df[(df["model_name"] == model_name) & (df["prompt_label"] == prompt_label)]
            generate_geval_file(filtered_df["response"].values, filtered_df["question"].values, score_file)

            if score_file.exists():
                score_df = pd.read_csv(score_file)
                for dim in GEVAL_DIMENSIONS:
                    if dim in score_df.columns:
                        results[key][dim].extend(score_df[dim].tolist())

    if not results:
        print("No G-Eval scores found.")
        return

    table_rows = []
    for (model_name, prompt_label), dim_scores in results.items():
        pretty_prompt_label = re.sub(r'_(\d+)_words', r' (\1 words)', prompt_label)
        pretty_prompt_label = re.sub(r'_', ' ', pretty_prompt_label)
        row = {"Model Name": model_name, "Prompt Type": pretty_prompt_label}
        dim_values = []
        for dim in GEVAL_DIMENSIONS:
            scores = dim_scores.get(dim, [])
            if scores:
                mean_score = sum(scores) / len(scores)
                std_score = (sum((x - mean_score) ** 2 for x in scores) / len(scores)) ** 0.5
                value_str = f"{mean_score:.2f} $\\pm$ {std_score:.2f}"
                row[dim] = value_str
                dim_values.append(mean_score)
            else:
                row[dim] = "N/A"
                dim_values.append(float('-inf'))
        agg_mean = sum([v for v in dim_values if v != float('-inf')]) / len(
            [v for v in dim_values if v != float('-inf')])
        row["Aggregate"] = agg_mean
        table_rows.append(row)

    table_df = pd.DataFrame(table_rows)
    table_df = table_df.sort_values(by=["Model Name", "Prompt Type"])

    for dim in GEVAL_DIMENSIONS:
        best = table_df[dim].apply(
            lambda x: float(re.search(r"([\d\.]+)", x).group(1)) if x != "N/A" else float('-inf')).max()
        table_df[dim] = table_df[dim].apply(
            lambda x: f"\\textbf{{{x}}}" if x != "N/A" and float(re.search(r"([\d\.]+)", x).group(1)) == best else x)
    best_agg = table_df["Aggregate"].max()
    table_df["Aggregate"] = table_df["Aggregate"].apply(
        lambda x: f"\\textbf{{{x:.2f}}}" if x == best_agg else f"{x:.2f}")

    latex_table = "\\begin{table*}[ht]\n\\centering\n"
    col_format = "c|l|" + "c" * len(GEVAL_DIMENSIONS) + "|c"
    latex_table += f"\\begin{{tabular}}{{{col_format}}}\n"
    latex_table += "\\hline\n"

    header = ["Model Name", "Prompt Type"] + GEVAL_DIMENSIONS + ["Aggregate"]
    latex_table += " & ".join(header) + " \\\\ \\hline\n"

    for model_name, group in table_df.groupby("Model Name"):
        safe_model_name = latex_escape(model_name)
        nrows = len(group)
        first_row = True
        gray = True

        for _, row in group.iterrows():
            prompt_label = latex_escape(row["Prompt Type"])
            values = [row[dim] for dim in GEVAL_DIMENSIONS] + [row["Aggregate"]]
            values = [prompt_label] + values

            colored_values = []
            for val in values:
                if gray:
                    colored_values.append(f"\\cellcolor{{gray!10}}{val}")
                else:
                    colored_values.append(val)
            gray = not gray

            if first_row:
                line = f"\\multirow{{{nrows}}}{{*}}{{\\centering {safe_model_name}}} & " + " & ".join(
                    colored_values) + " \\\\ \n"
                first_row = False
            else:
                line = f" & " + " & ".join(colored_values) + " \\\\ \n"
            latex_table += line

        latex_table += "\\hline\n"

    latex_table += "\\end{tabular}\n"
    latex_table += "\\caption{G-Eval scores by model and prompt type (mean $\\pm$ std).}\n"
    latex_table += "\\end{table*}\n"

    with open(ANALYSIS_PATH / "geval_scores_table.tex", "w") as f:
        f.write(latex_table)


if __name__ == '__main__':
    fire.Fire(generate_time_plot)
    fire.Fire(generate_token_length_response_plot)
    fire.Fire(generate_geval_latex_table)
    for dimension in GEVAL_DIMENSIONS:
        fire.Fire(lambda dim=dimension: generate_geval_score_plot(dim))