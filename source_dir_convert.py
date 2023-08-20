import os
import csv
import sys
import glob

output_file_level = '../File-level/'
output_line_level = '../Line-level/'

def extract_source_code(file_path):
    with open(file_path, 'r') as file:
        return file.read()

def generate_csv(rel):
    csv_file_level = rel+'_ground-truth-files_dataset.csv'
    csv_line_level = rel+'_defective_lines_dataset.csv'
    header = ['File', 'Bug','SRC']
    header_line_level = ['File', 'Line_number', 'SRC']
    rows = []

    java_files = glob.glob(os.path.join(rel, '**', '*.java'), recursive=True)
    for file_path in java_files:
        src_code = extract_source_code(file_path)
        rows.append([file_path, 'false',src_code])

    with open(output_file_level + csv_file_level, 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(header)
        writer.writerows(rows)

    print(f"CSV file '{csv_file_level}' generated successfully!")
    
    with open(output_line_level + csv_line_level, 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(header_line_level)

    print(f"CSV file '{csv_line_level}' generated successfully!")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Please provide the release file name as a command-line argument.")
        sys.exit(1)

    rel = sys.argv[1]
    generate_csv(rel)