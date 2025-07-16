import csv
import os

input_path = os.path.join(os.path.dirname(
    __file__), 'dataset', 'reference_data.csv')
output_path = os.path.join(os.path.dirname(
    __file__), 'dataset', 'data_cleaned.csv')


def clean_csv(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        for row in reader:
            if not row:
                continue
            # Join all columns to reconstruct the line
            line = ','.join(row)
            q_idx = line.find('?')
            if q_idx == -1:
                writer.writerow([line])
                continue
            question = line[:q_idx+1]
            answer = line[q_idx+1:]
            # Remove commas from answer
            answer_cleaned = answer.replace(',', '')
            writer.writerow([question, answer_cleaned.strip()])


if __name__ == '__main__':
    clean_csv(input_path, output_path)
    print(f'Cleaned CSV written to {output_path}')
