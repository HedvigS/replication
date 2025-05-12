from collections import defaultdict
import csv
from pyconcepticon import Concepticon
from clldutils.misc import slug
from tabulate import tabulate

conc = Concepticon('data/concepticon/')

joh = conc.conceptlists['Johansson-2020-344'].concepts
tad = conc.conceptlists['Tadmor-2009-100'].concepts
hol = conc.conceptlists['Holman-2008-40'].concepts
swad = conc.conceptlists['Swadesh-1955-100'].concepts

lists = [tad, hol, swad]
concepts = defaultdict()
added = []
missing = []

for concept in joh:
    concepts[joh[concept].concepticon_id] = joh[concept].concepticon_gloss

IDX = 345
for clist in lists:
    for item in clist:
        cid = clist[item].concepticon_id
        if cid not in concepts and cid not in added:
            gloss = clist[item].concepticon_gloss
            missing.append([(str(IDX)+'_'+slug(gloss)), gloss, clist[item].concepticon_id, gloss])
            IDX += 1
            added.append(cid)

print(tabulate(missing, tablefmt='tsv'))
with open('data/missing_concepts.csv', 'w', newline='', encoding='utf8') as file:
    w = csv.writer(file)
    w.writerows(missing)
