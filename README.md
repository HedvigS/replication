# Replicating sound symbolism

This repository is the replication study of Johansson et al. (2020, [link](https://doi.org/10.1515/lingty-2020-2034)). The original study built a model to investigate the statistical over-representation of certain phonetic features in concepts of basic vocabulary.

## Requirements

### Python packages

We recommend to install the Python packages in a fresh virtual environment. For example, you can follow this code to create one:

```shell
python3 -m venv venv/replication
source venv/replication/bin/activate
```

You can now install the packages with pip. We have used Python 3.13 for the code. Older versions might not work for the provided package versions.

```shell
pip install -r requirements.txt
```

For Windows, please follow this tutorial: <https://doi.org/10.15475/calcip.2024.2.6>

### R packages

Some code is also in R. You can install all the necessary packages through `renv`. Just run the code that you can find in `00_utils/packages.R`:

```R
install.packages('renv')
library(renv)
renv::restore()
```

This should install all the required packages with working versions.

In order to use `cmdstanr` as backend for brms/Stan, you need to have a running installation of `cmdstan` on your computer. You can follow the install recommendations [here](https://github.com/stan-dev/cmdstanr?tab=readme-ov-file#installation).

## Downloading the data

```shell
cd 01_preprocessing
git clone https://github.com/cldf-clts/clts data/clts --branch v2.3.0
git clone https://github.com/lexibank/lexibank-analysed.git data/lexibank-analysed --branch v2.1
git clone https://github.com/lexibank/johanssonsoundsymbolic data/johanssonsoundsymbolic --branch v1.3
git clone https://github.com/glottolog/glottolog-cldf data/glottolog --branch v5.1
git clone https://github.com/concepticon/concepticon-data data/concepticon --branch v3.4.0
```

We have to add the missing concepts to the database from the original study.

```shell
python check_conceptlists.py
cat data/missing_concepts.csv >> data/johanssonsoundsymbolic/cldf/parameters.csv
```

You can now create the SQLite3 databases for all the data necessary to run the query and the models.

```shell
rm data/*.sqlite3
cldf createdb data/clts/cldf-metadata.json data/clts.sqlite3
cldf createdb data/lexibank-analysed/cldf/wordlist-metadata.json data/lexibank.sqlite3
cldf createdb data/johanssonsoundsymbolic/cldf/cldf-metadata.json data/johanssonsoundsymbolic.sqlite3
cldf createdb data/glottolog/cldf/cldf-metadata.json data/glottolog.sqlite3
```

Now you can create the `data.csv` file for further processing by retrieving the data from Lexibank: `python query.py`.

## Running the analysis

We can now switch to the `02_analysis` folder.

```shell
cd ../02_analysis
```

### File overview

- `01_priors.R` - The distributions for my priors.
- `02_preprocess.R` - This script returns the data files for the individual phonetic categories. Creates
- `03_models.R` - Running the model for all 10 phonetic categories.
- `04_plots.R` - Loading the individual results and comparing them to the original results.

The models and posterior predictive simulations can be accessed on OSF: <>

Please extract the two folders (`posterior_draws/` and `models/`) and put them into the main folder in order to have the directory-setup working.

### Evaluation thresholds

The original authors use the logaritm with base 2 for computing the log odds ratio, and use `log2(1.2)` as a threshold that gets added and substracted to 1, in order to prepare the evaluation thresholds. To follow more standard practices in statistics and machine learning, we use the natural logarithm instead. The authors claimed in the paper to use the factor of 1.25 as factor for the threshold, while in the published script they used a factor of 1.2. It is thus unclear which one was indeed used, but I suspect that it was 1.2, since this is what is published in the script. The following are the new thresholds used in our paper:

- Lower threshold: `log(1/1.25)`
- Upper threshold: `log(1*1.25)`

### Computing Proportions

Mirroring the approach from the original authors, I use dirichlet models for the individual phonetic features. This involves computing the proportions of features per word. In many cases, those will be 0. However, due to the set-up of the script, an `NA` term is produced. In order to correctly represent this, those `NA` get changed to `0.001` (Dirichlect requires a response above 0). This is exactly the same procedure as in the original study, and is justified by design.

## Evaluating the results

The final folder, `03_evaluation`, represents a numeric comparison between the old and the new results. You can run `intersection.py` to receive an overview of all the effects found for concepts in the basic vocabulary lists.

## References

Erben Johansson, N., Anikin, A., Carling, G., & Holmer, A. (2020). The typology of sound symbolism: Defining macro-concepts via their semantic and phonetic features. Linguistic Typology, 24(2), 253–310. https://doi.org/10.1515/lingty-2020-2034
