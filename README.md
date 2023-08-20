# thesis-artifacts
## Description
This repository contains the files used to assist in cross-project defect prediction of new software applications using DeepLineDP (https://github.com/awsm-research/DeepLineDP).

## File descriptions
`source_dir_convert.py`: Run in the directory where the root of your target software project resides to generate file-level and line-level csv files.

`combine_preprocessed_datasets.py`: Run in the same directory as e.g., multiple test releases to combine their csv files.

`get_cross-project_metrics.R`: Place in DeepLineDP/script/ and run to generate cross-project metrics. Edit the definition of variable 'projs' to define the training set.

`LineColourAction.kt`: The code for the IntelliJ IDEA plugin's highlighting action.
