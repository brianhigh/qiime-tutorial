#!/bin/sh

# ----------------------------------------------------------------------
#                            Qiime Tutorial
# ----------------------------------------------------------------------
#
# This bash script runs the commands listed in an online Qiime tutorial.
#
# Based on:
# 
# * Werner Lab Qiime Overview Tutorial
#     http://www.wernerlab.org/teaching/qiime/overview
# * Qiime.org Qiime Tutorial
#     http://qiime.org/tutorials/tutorial.html

# ------------
# Get the data
# ------------

# Download and extract the data archive, if this has not already been done.
if [ ! -d qiime_overview_tutorial ]; then \
    if [ ! -f qiime_overview_tutorial.zip ]; then \
        wget -q 'ftp://ftp.microbio.me/pub/qiime-files/qiime_overview_tutorial.zip'
    fi
    unzip -q -o qiime_overview_tutorial.zip
fi

# Change the working directory (i.e., enter the data folder).
cd qiime_overview_tutorial

# ----------------------
# Examine the data files
# ----------------------

# View the first record (6 lines) in `Fasting_Example.fna`.
head -6 Fasting_Example.fna

# Count the number of records in `Fasting_Example.fna`.
grep -c ">" Fasting_Example.fna

# View the first record (6 lines) in `Fasting_Example.qual`.
head -6 Fasting_Example.qual

# Count the number of records in `Fasting_Example.qual`.
grep -c ">" Fasting_Example.qual

# View the `Fasting_Map.txt` file.
cat Fasting_Map.txt 

# -----------------
# Trim the barcodes
# -----------------

split_libraries.py -m Fasting_Map.txt -f Fasting_Example.fna \
    -q Fasting_Example.qual -o split_library_output/

# View the folder which was created.
ls -lh split_library_output/

# View the logfile.
cat split_library_output/split_library_log.txt

# View the first record (2 lines) in `split_library_output/seqs.fna`.
head -2 split_library_output/seqs.fna

# -------
# Denoise
# -------

if [ ! -d denoiser ]; then \
    # This might take up to an hour to run...
    denoise_wrapper.py -i Fasting_Example.sff.txt \
        -f split_library_output/seqs.fna -m Fasting_Map.txt -o denoiser/
fi

inflate_denoiser_output.py -c denoiser/centroids.fasta \
    -s denoiser/singletons.fasta -f split_library_output/seqs.fna \
    -d denoiser/denoiser_mapping.txt -o inflated_denoised_seqs.fna

# View the first 10 lines of `inflated_denoised_seqs.fna`.
head inflated_denoised_seqs.fna

# ---------
# Pick OTUs
# ---------

pick_otus.py -i inflated_denoised_seqs.fna

# View the first 10 lines of `inflated_denoised_seqs_otus.txt`.
head uclust_picked_otus/inflated_denoised_seqs_otus.txt

# Pick one representative sequence per OTU.
pick_rep_set.py -i uclust_picked_otus/inflated_denoised_seqs_otus.txt \
    -f inflated_denoised_seqs.fna -o rep_set.fna

# Count number of sequences in resulting FASTA file.
grep -c ">" rep_set.fna

# View first two records (4 lines) of the `rep_set.fna` file.
head -4 rep_set.fna

# ---------------
# Assign Taxonomy
# ---------------

assign_taxonomy.py -i rep_set.fna -o taxonomy_results/

# ---------------
# Build OTU Table
# ---------------

make_otu_table.py -i uclust_picked_otus/inflated_denoised_seqs_otus.txt \
    -t taxonomy_results/rep_set_tax_assignments.txt -o otu_table.biom

# Convert to text format.
biom convert -i otu_table.biom -o otu_table_tabseparated.txt \
    --to-tsv --header-key taxonomy --output-metadata-id "ConsensusLineage"

# View the frist 10 lines of `otu_table_tabseparated.txt`.
head otu_table_tabseparated.txt

# -------------------
#  Summarize Taxonomy
# -------------------

summarize_taxa.py -i otu_table.biom -o taxonomy_summaries/

# Make html reports containing plots.
plot_taxa_summary.py -i taxonomy_summaries/otu_table_L3.txt \
    -o taxonomy_plot_L3/

# ----------------------------------
# Make a Multiple Sequence Alignment
# ----------------------------------

align_seqs.py -i rep_set.fna -o alignment/

# Filter the alignment to aid the building of phylogenetic tree
filter_alignment.py -i alignment/rep_set_aligned.fasta -o alignment/

# -------------------------
# Build a phylogenetic tree
# -------------------------

make_phylogeny.py -i alignment/rep_set_aligned_pfiltered.fasta \
    -o rep_set_tree.tre

# -----------------------------
# Perform Multiple Rarefactions
# -----------------------------

multiple_rarefactions.py -i otu_table.biom -m 20 -x 100 -s 20 -n 10 \
    -o rare_20-100/

# -------------------------
# Calculate Alpha Diversity
# -------------------------

alpha_diversity.py -i rare_20-100/ -o alpha_rare/ -t rep_set_tree.tre \
    -m observed_species,chao1,PD_whole_tree

# ----------------------------------
# Summarize the Alpha Diversity Data
# ----------------------------------

collate_alpha.py -i alpha_rare/ -o alpha_collated/

# ----------------------------------
# Jackknifed beta diversity analysis
# ----------------------------------

jackknifed_beta_diversity.py -i otu_table.biom \
    -o jackknifed_beta_diversity/ -e 90 \
    -m Fasting_Map.txt -t rep_set_tree.tre

# -------------------
# Distance Statistics
# -------------------

dissimilarity_mtx_stats.py \
    -i jackknifed_beta_diversity/unweighted_unifrac/rare_dm/ \
    -o unweighted_unifrac_stats/

# Make distance boxplots
make_distance_boxplots.py -m Fasting_Map.txt -o distance_boxplots \
    -d unweighted_unifrac_stats/means.txt -f Treatment --save_raw_data
