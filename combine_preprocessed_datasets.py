import os
import csv
import sys
csv.field_size_limit(sys.maxsize)

def combine_csv_files():
    combined_rows = []
    
    for filename in os.listdir():
        if filename.endswith('.csv'):
            try:
                with open(filename, 'r') as file:
                    reader = csv.reader(file)
                    rows = list(reader)

                    rows = rows[1:]
                    combined_rows.extend(rows)

            except Exception:
                print("Error reading '{0}'.".format(filename))
                sys.exit(0)    

    combined_filename = 'combined-release.csv'
    try:
        with open(combined_filename, 'w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(['filename', 'is_test_file', 'code_line', 'line_number', 'is_comment', 'is_blank', 'file-label', 'line-label'])
            writer.writerows(combined_rows)
    except Exception:
        print("Error writing '{0}'.".format(combined_filename))
        sys.exit(0)  
    print(f"Combined CSV file '{combined_filename}' created successfully!")

combine_csv_files()