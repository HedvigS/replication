import csv
from csvw.dsv import UnicodeDictReader
from collections import defaultdict
from tabulate import tabulate


def read_cl(path):
    concept_dict = defaultdict()
    with UnicodeDictReader(path, delimiter='\t') as f:
        for lin in f:
            concept_dict[lin["CONCEPTICON_GLOSS"]] = lin['CONCEPTICON_ID']
    return concept_dict


BASE = "data/concepticon/concepticondata/conceptlists/"

# Use local manipulation of Johansson to account for replaced '_' and brackets
JOHANSSON = "Johansson-2020-344.tsv"
TAD_100 = BASE + "Tadmor-2009-100.tsv"
SWAD_100 = BASE + "Swadesh-1955-100.tsv"
ASJP_40 = BASE + "Holman-2008-40.tsv"

# Get Concepticon mappings of the Johansson concept list
change = defaultdict()
symbolic_concepts = []
with UnicodeDictReader(JOHANSSON, delimiter='\t') as reader:
    for line in reader:
        change[line['LEXIBANK_GLOSS']] = line["CONCEPTICON_GLOSS"]
        if line['SOUND_SYMBOLIC'] == str(1):
            symbolic_concepts.append(line["CONCEPTICON_GLOSS"])

orig_results = []
missing_concepts = []
mapped_conc = []
# Read in original results
with open('original_results.csv', mode='r', encoding="utf8") as file:
    data = csv.reader(file)
    # next(data)
    for i, line in enumerate(data):
        # Check the unmapped concepts
        if line[0] not in missing_concepts:
            missing_concepts.append(line[0])

        if i == 0:
            mapped_conc.append(line)

        else:
            mod = change[line[0].replace('_', ' ').replace('fs', '(fs)').replace('ms', '(ms)')]
            if mod != '':
                line[0] = mod
                orig_results.append([
                    line[0],  # Concept
                    line[1]   # Feature
                    ])

                mapped_conc.append(line)


# Write mapped original results to file for R plots
with open('../02_analysis/original_results_mapped.csv', 'w', encoding='utf8', newline='') as f:
    writer = csv.writer(f, delimiter='\t')
    writer.writerows(mapped_conc)

# Read in the vocabulary lists
lists = defaultdict()
lists = {name: read_cl(file) for name, file in [
    ('Swadesh-100', SWAD_100),
    ('Tadmor-100', TAD_100),
    ('Holman-40', ASJP_40)
    ]}

results = []
table = []

with open('../02_analysis/data/final_results.csv', mode='r', encoding="utf8") as file:
    data = csv.reader(file)
    headers = next(data)
    for line in data:
        results.append([
            line[0],  # Concept
            line[1],  # Feature
            line[7],  # New/Original
            line[9]   # Strong/Weak
            ])

rep_score = defaultdict()

# Cycling through all basic vocabulary lists that interest us
for bsc_vcb in lists:
    print('------------')
    print('Results for', bsc_vcb)

    original_effects = defaultdict()
    replicated_effects = defaultdict()
    new_effects = defaultdict()
    all_results = []
    # Establish baseline for quantiyfying the replication
    # Dictionary with structure key:CONCEPT value: [features]
    # e.g. STONE ['nasal', 'nasal+voice']
    for item in results:
        # Check if concept is in basic vocabulary list
        if item[0] in lists[bsc_vcb] and item[2] == 'Original Results' and item[0] in symbolic_concepts:
            # Add concept if not yet in dictionary
            if item[0] not in original_effects:
                original_effects[item[0]] = []
            original_effects[item[0]].append(item[1])  # Feature

    # Go through new results
    for entry in results:
        if entry[0] in lists[bsc_vcb] and entry[2] == 'New Results':  # and entry[1] != 'high-back-rounded':
            # Get number of concepts for which an effect has been found
            if entry[0] not in all_results:
                all_results.append(entry[0])
            # Check if pattern had been observed previously, for concept and feature
            if entry[0] in original_effects:
                if entry[1] in original_effects[entry[0]]:
                    if entry[0] not in replicated_effects:
                        replicated_effects[entry[0]] = []
                    replicated_effects[entry[0]].append(entry[1])

                else:
                    if entry[0] not in new_effects:
                        new_effects[entry[0]] = []
                    new_effects[entry[0]].append(entry[1])

    rep_score[bsc_vcb] = len(replicated_effects) / len(lists[bsc_vcb])
    print('------------')

    print('Original:', len(original_effects))

    print('Replicated:', len(replicated_effects))
    for item in replicated_effects:
        print(item, replicated_effects[item])

    print('------------')
    print('New effects:', len(new_effects))
    for item in new_effects:
        if item in original_effects:
            print('Old:', item, original_effects[item])
        print('New:', item, new_effects[item])

# rounded and not high-back: # ℹ 8,354 more rows
# rounded and high back: # ℹ 267,056 more rows

    table.append([
        bsc_vcb,
        len(original_effects),
        len(all_results),
        len(all_results)/len(lists[bsc_vcb]),
        len(replicated_effects),
        len(replicated_effects) / len(original_effects)
        ])

header = ['Vocabulary list', 'Original (n)', 'New (n)', 'New (%)', 'Replicated (n)', 'Replicated (%)']
print('------------')
print(tabulate(
    table,
    headers=header,
    floatfmt='.3f',
    tablefmt='latex'
    ))
